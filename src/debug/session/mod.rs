mod events;
mod handshake;
mod progress;
mod requests;
mod store;
mod wire;

use std::collections::BTreeMap;
use std::path::Path;
use std::sync::{Arc, Mutex, Weak};
use std::thread;
use std::time::Duration;

use crate::error::EngineError;
use crate::ffi::{Breakpoint, DebugEvent, DebugLaunch, DebugListener, DebugState, DebugThread};

use super::protocol::Capabilities;
use super::registry::DebugRegistry;
use super::transport::Transport;
use progress::Progress;

const DRAIN_TIMEOUT: Duration = Duration::from_secs(5);

struct Registration {
    registry: Weak<DebugRegistry>,
    id: u64,
}

pub struct DebugSession {
    transport: Transport,
    listener: Arc<dyn DebugListener>,
    launch: DebugLaunch,
    state: Mutex<DebugState>,
    capabilities: Mutex<Capabilities>,
    breakpoints: Mutex<BTreeMap<String, Vec<Breakpoint>>>,
    threads: Mutex<Vec<DebugThread>>,
    registration: Mutex<Option<Registration>>,
    progress: Progress,
}

impl DebugSession {
    pub fn start(
        adapter: &Path,
        arguments: &[String],
        launch: DebugLaunch,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<Arc<Self>, EngineError> {
        let transport = Transport::spawn(adapter, arguments)?;
        let session = Arc::new(Self {
            transport,
            listener,
            launch,
            state: Mutex::new(DebugState::Launching),
            capabilities: Mutex::new(Capabilities::default()),
            breakpoints: Mutex::new(store::group(breakpoints)),
            threads: Mutex::new(Vec::new()),
            registration: Mutex::new(None),
            progress: Progress::default(),
        });
        session.emit(DebugEvent::Launching);
        let worker = Arc::clone(&session);
        thread::spawn(move || {
            if let Err(err) = handshake::run(&worker) {
                worker.fail(&err.to_string());
                return;
            }
            events::pump(&worker);
        });
        Ok(session)
    }

    pub fn attach(self: &Arc<Self>, registry: &Arc<DebugRegistry>, id: u64) {
        if let Ok(mut slot) = self.registration.lock() {
            *slot = Some(Registration {
                registry: Arc::downgrade(registry),
                id,
            });
        }
        if self.ended() {
            self.retire();
        }
    }

    pub fn shutdown(&self) {
        let entered = self.transition(DebugState::Terminated);
        self.transport.shutdown();
        if entered {
            self.emit(DebugEvent::Terminated);
        }
    }

    pub fn state(&self) -> DebugState {
        self.state
            .lock()
            .map(|state| state.clone())
            .unwrap_or(DebugState::Terminated)
    }

    pub fn stopped_thread(&self) -> Option<i64> {
        match self.state() {
            DebugState::Stopped { thread_id, .. } => Some(thread_id),
            _ => self.threads.lock().ok()?.first().map(|thread| thread.id),
        }
    }

    pub fn breakpoints(&self, path: &str) -> Vec<Breakpoint> {
        self.breakpoints
            .lock()
            .ok()
            .and_then(|store| store.get(path).cloned())
            .unwrap_or_default()
    }

    pub(super) fn transition(&self, state: DebugState) -> bool {
        let ending = matches!(state, DebugState::Terminated | DebugState::Exited { .. });
        let entered =
            self.replace_state(|current| !matches!(current, DebugState::Terminated), state);
        if entered && ending {
            self.retire();
        }
        entered
    }

    pub(super) fn begin_running(&self) -> bool {
        self.replace_state(
            |current| matches!(current, DebugState::Launching),
            DebugState::Running,
        )
    }

    fn replace_state(&self, allowed: impl Fn(&DebugState) -> bool, state: DebugState) -> bool {
        let mut current = self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if !allowed(&current) {
            return false;
        }
        *current = state;
        true
    }

    pub(super) fn mark_processed(&self, stamp: u64) {
        self.progress.mark(stamp);
    }

    pub(super) fn drained(&self, mark: u64) -> bool {
        self.progress.wait(mark, DRAIN_TIMEOUT)
    }

    fn retire(&self) {
        let taken = self
            .registration
            .lock()
            .ok()
            .and_then(|mut slot| slot.take());
        let Some(registration) = taken else {
            return;
        };
        let Some(registry) = registration.registry.upgrade() else {
            return;
        };
        registry.remove(registration.id);
    }

    fn emit(&self, event: DebugEvent) {
        self.listener.on_event(event);
    }

    pub(super) fn fail(&self, message: &str) {
        self.emit(DebugEvent::Failed {
            message: message.to_string(),
        });
        if self.transition(DebugState::Terminated) {
            self.emit(DebugEvent::Terminated);
        }
    }

    fn finished(&self) -> bool {
        matches!(self.state(), DebugState::Terminated)
    }

    fn ended(&self) -> bool {
        matches!(
            self.state(),
            DebugState::Terminated | DebugState::Exited { .. }
        )
    }
}
