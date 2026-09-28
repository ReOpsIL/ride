use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use crate::ffi::CompletionHit;

use super::board::Board;
use super::facts::Facts;
use super::fleet::Fleet;
use super::key::SiteKey;

#[derive(Default)]
pub struct Shared {
    pub board: Board,
    pub fleet: Fleet,
    pub cache: PathBuf,
    facts: Mutex<Facts>,
    synced: Mutex<HashMap<u64, u64>>,
    pending: Mutex<HashSet<SiteKey>>,
}

impl Shared {
    pub fn new(cache: PathBuf) -> Self {
        Self {
            cache,
            ..Self::default()
        }
    }

    pub fn hits(&self, key: &SiteKey) -> Option<Arc<[CompletionHit]>> {
        lock(&self.facts).hits(key)
    }

    pub fn is_pending(&self, key: &SiteKey) -> bool {
        lock(&self.pending).contains(key)
    }

    pub fn claim(&self, key: SiteKey) -> bool {
        lock(&self.pending).insert(key)
    }

    pub fn done(&self, key: &SiteKey) {
        lock(&self.pending).remove(key);
    }

    pub fn synced_version(&self, session_id: u64) -> Option<u64> {
        lock(&self.synced).get(&session_id).copied()
    }

    pub fn mark_synced(&self, session_id: u64, version: u64) {
        lock(&self.synced).insert(session_id, version);
    }

    pub fn unmark(&self, session_id: u64) {
        lock(&self.synced).remove(&session_id);
    }

    pub fn store(&self, key: SiteKey, hits: Vec<CompletionHit>) {
        lock(&self.facts).insert(key, hits);
        self.board.completions_ready(key.session_id);
    }

    pub fn forget(&self, session_id: u64) {
        lock(&self.facts).forget(session_id);
        self.unmark(session_id);
    }

    pub fn reset(&self) {
        lock(&self.facts).clear();
        lock(&self.synced).clear();
        lock(&self.pending).clear();
    }
}

pub fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}
