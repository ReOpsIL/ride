mod events;
mod handshake;
mod lifecycle;
mod progress;
mod registration;
mod requests;
mod store;
mod wire;

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use crate::error::EngineError;
use crate::ffi::{Breakpoint, DebugEvent, DebugLaunch, DebugListener, DebugState, DebugThread};

use super::protocol::Capabilities;
use super::registry::DebugRegistry;
use super::transport::Transport;
use progress::Progress;
use registration::Registration;

const DRAIN_TIMEOUT: Duration = Duration::from_secs(5);

pub struct DebugSession {
    transport: Transport,
    listener: Arc<dyn DebugListener>,
    launch: DebugLaunch,
    sysroot: Option<PathBuf>,
    state: Mutex<DebugState>,
    capabilities: Mutex<Capabilities>,
    breakpoints: Mutex<BTreeMap<String, Vec<Breakpoint>>>,
    threads: Mutex<Vec<DebugThread>>,
    registration: Registration,
    progress: Progress,
}

impl DebugSession {
    pub fn start(
        adapter: &Path,
        arguments: &[String],
        launch: DebugLaunch,
        sysroot: Option<PathBuf>,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<Arc<Self>, EngineError> {
        let transport = Transport::spawn(adapter, arguments)?;
        let session = Arc::new(Self {
            transport,
            listener,
            launch,
            sysroot,
            state: Mutex::new(DebugState::Launching),
            capabilities: Mutex::new(Capabilities::default()),
            breakpoints: Mutex::new(store::group(breakpoints)),
            threads: Mutex::new(Vec::new()),
            registration: Registration::default(),
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
        self.registration.set(registry, id);
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

    pub(super) fn mark_processed(&self, stamp: u64) {
        self.progress.mark(stamp);
    }

    pub(super) fn drained(&self, mark: u64) -> bool {
        self.progress.wait(mark, DRAIN_TIMEOUT)
    }

    pub(super) fn emit(&self, event: DebugEvent) {
        self.listener.on_event(event);
    }

    pub(super) fn emit_failure(&self, message: &str) {
        self.emit(DebugEvent::Failed {
            message: message.to_string(),
        });
        self.emit(DebugEvent::Terminated);
    }
}
