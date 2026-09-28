use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};

use crate::ffi::{CompletionHit, OracleListener, OracleState, OracleStatus};

use super::job::MemberJob;
use super::key::MemberKey;
use super::shared::{Shared, lock};
use super::worker::{self, Msg};

#[derive(Default)]
pub struct Oracle {
    shared: Arc<Shared>,
    sender: Mutex<Option<Sender<Msg>>>,
}

impl Oracle {
    pub fn set_enabled(&self, enabled: bool) {
        let mut sender = lock(&self.sender);
        match (enabled, sender.take()) {
            (true, None) => {
                *sender = worker::spawn(Arc::clone(&self.shared));
                let state = if sender.is_some() {
                    OracleState::Idle
                } else {
                    OracleState::Failed
                };
                self.shared.board.set(state, None);
            }
            (false, Some(running)) => {
                let _ = running.send(Msg::Quit);
                self.shared.reset();
                self.shared.board.set(OracleState::Off, None);
            }
            (_, running) => *sender = running,
        }
    }

    pub fn status(&self) -> OracleStatus {
        self.shared.board.status()
    }

    pub fn listen(&self, listener: Arc<dyn OracleListener>) {
        self.shared.board.listen(listener);
    }

    pub fn members(&self, key: &MemberKey) -> Option<Arc<[CompletionHit]>> {
        self.shared.members(key)
    }

    pub fn wants(&self, key: &MemberKey) -> bool {
        lock(&self.sender).is_some() && !self.shared.is_pending(key)
    }

    pub fn synced_version(&self, session_id: u64) -> Option<u64> {
        self.shared.synced_version(session_id)
    }

    pub fn request(&self, job: MemberJob) {
        let key = job.key;
        if self.shared.claim(key) && !self.send(Msg::Members(job)) {
            self.shared.done(&key);
        }
    }

    pub fn forget(&self, session_id: u64) {
        self.shared.forget(session_id);
        self.send(Msg::Close(session_id));
    }

    pub fn stop_all(&self) {
        self.shared.reset();
        self.send(Msg::StopAll);
    }

    fn send(&self, msg: Msg) -> bool {
        lock(&self.sender)
            .as_ref()
            .is_some_and(|sender| sender.send(msg).is_ok())
    }
}

impl Drop for Oracle {
    fn drop(&mut self) {
        self.send(Msg::Quit);
    }
}
