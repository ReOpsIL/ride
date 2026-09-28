use std::path::PathBuf;
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};

use crate::ffi::{CompletionHit, OracleListener, OracleState, OracleStatus};

use super::definition;
use super::error::OracleError;
use super::hover::Hover;
use super::job::DocText;
use super::job::SiteJob;
use super::key::SiteKey;
use super::shared::{Shared, lock};
use super::sidecar::Sidecar;
use super::target::Target;
use super::worker::{self, Msg};

pub struct Oracle {
    shared: Arc<Shared>,
    sender: Mutex<Option<Sender<Msg>>>,
}

impl Oracle {
    pub fn new(cache: PathBuf) -> Self {
        Self {
            shared: Arc::new(Shared::new(cache)),
            sender: Mutex::default(),
        }
    }

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

    pub fn hits(&self, key: &SiteKey) -> Option<Arc<[CompletionHit]>> {
        self.shared.hits(key)
    }

    pub fn wants(&self, key: &SiteKey) -> bool {
        lock(&self.sender).is_some() && !self.shared.is_pending(key)
    }

    pub fn synced_version(&self, session_id: u64) -> Option<u64> {
        self.shared.synced_version(session_id)
    }

    pub fn request(&self, job: SiteJob) {
        let key = job.key;
        if self.shared.claim(key) && !self.send(Msg::Complete(job)) {
            self.shared.done(&key);
        }
    }

    pub fn definitions(&self, doc: DocText, stale: &[DocText], site: usize) -> Vec<Target> {
        self.with_ready(doc, stale, |sidecar, doc| {
            definition::gather(sidecar, doc, site, stale)
        })
        .unwrap_or_default()
    }

    pub fn hover(&self, doc: DocText, stale: &[DocText], site: usize) -> Option<Hover> {
        self.with_ready(doc, stale, |sidecar, doc| sidecar.hover(doc, site))
            .flatten()
    }

    fn with_ready<T>(
        &self,
        doc: DocText,
        stale: &[DocText],
        ask: impl FnOnce(&Sidecar, &DocText) -> Result<T, OracleError>,
    ) -> Option<T> {
        if lock(&self.sender).is_none() {
            return None;
        }
        let key = self.shared.fleet.key_for(&doc)?;
        let ready = self
            .shared
            .fleet
            .get(&key)
            .filter(|s| s.ready() && s.failure().is_none());
        let Some(sidecar) = ready else {
            self.send(Msg::Warm(doc));
            return None;
        };
        let shared = &self.shared;
        sidecar
            .sync_all(&doc, stale, |id, version| shared.mark_synced(id, version))
            .and_then(|()| ask(&sidecar, &doc))
            .ok()
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
