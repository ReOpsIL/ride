use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use crate::error::EngineError;
use crate::ffi::{Breakpoint, DebugLaunch, DebugListener};

use super::session::DebugSession;

#[derive(Default)]
pub struct DebugRegistry {
    next: AtomicU64,
    sessions: Mutex<HashMap<u64, Arc<DebugSession>>>,
}

impl DebugRegistry {
    pub fn start(
        self: &Arc<Self>,
        adapter: &Path,
        arguments: &[String],
        launch: DebugLaunch,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<u64, EngineError> {
        let id = self.reserve();
        let session = DebugSession::start(adapter, arguments, launch, breakpoints, listener)?;
        self.insert(id, Arc::clone(&session));
        session.attach(self, id);
        Ok(id)
    }

    pub fn reserve(&self) -> u64 {
        self.next.fetch_add(1, Ordering::SeqCst) + 1
    }

    pub fn insert(&self, id: u64, session: Arc<DebugSession>) {
        if let Ok(mut sessions) = self.sessions.lock() {
            sessions.insert(id, session);
        }
    }

    pub fn get(&self, id: u64) -> Option<Arc<DebugSession>> {
        self.sessions.lock().ok()?.get(&id).cloned()
    }

    pub fn remove(&self, id: u64) -> Option<Arc<DebugSession>> {
        self.sessions.lock().ok()?.remove(&id)
    }
}
