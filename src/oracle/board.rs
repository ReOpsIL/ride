use std::sync::{Arc, Mutex};

use crate::ffi::{OracleListener, OracleState, OracleStatus};

use super::error::OracleError;
use super::shared::lock;

#[derive(Default)]
pub struct Board {
    status: Mutex<OracleStatus>,
    listener: Mutex<Option<Arc<dyn OracleListener>>>,
}

impl Board {
    pub fn status(&self) -> OracleStatus {
        lock(&self.status).clone()
    }

    pub fn set(&self, state: OracleState, message: Option<String>) {
        let next = OracleStatus { state, message };
        {
            let mut status = lock(&self.status);
            if *status == next {
                return;
            }
            *status = next.clone();
        }
        if let Some(listener) = self.listener() {
            listener.on_oracle_status(next);
        }
    }

    pub fn fail(&self, err: &OracleError) {
        let state = match err {
            OracleError::NotInstalled { .. } => OracleState::Unavailable,
            _ => OracleState::Failed,
        };
        self.set(state, Some(err.to_string()));
    }

    pub fn completions_ready(&self, session_id: u64) {
        if let Some(listener) = self.listener() {
            listener.on_completions_ready(session_id);
        }
    }

    pub fn listen(&self, listener: Arc<dyn OracleListener>) {
        *lock(&self.listener) = Some(Arc::clone(&listener));
        listener.on_oracle_status(self.status());
    }

    fn listener(&self) -> Option<Arc<dyn OracleListener>> {
        lock(&self.listener).clone()
    }
}
