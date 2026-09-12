mod events;
mod handshake;
mod requests;
mod store;
mod wire;

use std::collections::BTreeMap;
use std::path::Path;
use std::sync::{Arc, Mutex, Weak};
use std::thread;

use crate::error::EngineError;
use crate::ffi::{Breakpoint, DebugEvent, DebugLaunch, DebugListener, DebugState, DebugThread};

use super::protocol::Capabilities;
use super::registry::DebugRegistry;
use super::transport::Transport;

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
        if self.finished() {
            self.retire();
        }
    }

    pub fn shutdown(&self) {
        let ended = self.finished();
        self.set_state(DebugState::Terminated);
        self.transport.shutdown();
        if !ended {
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

    fn set_state(&self, state: DebugState) {
        let ending = matches!(state, DebugState::Terminated | DebugState::Exited { .. });
        if let Ok(mut current) = self.state.lock() {
            *current = state;
        }
        if ending {
            self.retire();
        }
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

    fn fail(&self, message: &str) {
        self.emit(DebugEvent::Failed {
            message: message.to_string(),
        });
        self.set_state(DebugState::Terminated);
        self.emit(DebugEvent::Terminated);
    }

    fn finished(&self) -> bool {
        matches!(self.state(), DebugState::Terminated)
    }
}
