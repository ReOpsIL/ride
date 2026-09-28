use std::sync::Arc;

use crate::ffi::OracleState;

use super::discover;
use super::error::OracleError;
use super::fleet::Key;
use super::restarts::Restarts;
use super::server::Server;
use super::shared::Shared;
use super::sidecar::Sidecar;

pub struct Launcher {
    shared: Arc<Shared>,
    restarts: Restarts<Key>,
}

impl Launcher {
    pub fn new(shared: Arc<Shared>) -> Self {
        Self {
            shared,
            restarts: Restarts::default(),
        }
    }

    pub fn ensure(&mut self, key: &Key) -> Result<Arc<Sidecar>, OracleError> {
        if let Some(sidecar) = self.shared.fleet.get(key) {
            return Ok(sidecar);
        }
        let (server, root) = key;
        if self.restarts.exhausted(key) {
            let place = format!("{} in {}", server.name(), root.display());
            return Err(OracleError::GaveUp(place));
        }
        self.announce(OracleState::Starting, *server);
        let program = discover::program(*server)?;
        let sidecar = Sidecar::start(*server, &program, root, &self.shared.cache)
            .inspect_err(|_| self.restarts.record(key))?;
        let sidecar = Arc::new(sidecar);
        self.shared.fleet.insert(key.clone(), Arc::clone(&sidecar));
        Ok(sidecar)
    }

    pub fn check_exit(&mut self, key: &Key) {
        let Some(exit) = self.shared.fleet.get(key).and_then(|s| s.failure()) else {
            return;
        };
        if let Some(sidecar) = self.shared.fleet.remove(key) {
            for session_id in sidecar.sessions() {
                self.shared.unmark(session_id);
            }
        }
        self.restarts.record(key);
        let message = format!("{}: {exit}", key.0.name());
        self.shared.board.set(OracleState::Failed, Some(message));
    }

    pub fn announce(&self, state: OracleState, server: Server) {
        self.shared
            .board
            .set(state, Some(server.name().to_string()));
    }

    pub fn reset(&mut self) {
        self.shared.fleet.clear();
        self.restarts.clear();
        self.shared.board.set(OracleState::Idle, None);
    }
}
