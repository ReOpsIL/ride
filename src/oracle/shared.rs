use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use crate::ffi::CompletionHit;

use super::board::Board;
use super::facts::Facts;
use super::key::MemberKey;

#[derive(Default)]
pub struct Shared {
    pub board: Board,
    facts: Mutex<Facts>,
    synced: Mutex<HashMap<u64, u64>>,
    pending: Mutex<HashSet<MemberKey>>,
}

impl Shared {
    pub fn members(&self, key: &MemberKey) -> Option<Arc<[CompletionHit]>> {
        lock(&self.facts).members(key)
    }

    pub fn is_pending(&self, key: &MemberKey) -> bool {
        lock(&self.pending).contains(key)
    }

    pub fn claim(&self, key: MemberKey) -> bool {
        lock(&self.pending).insert(key)
    }

    pub fn done(&self, key: &MemberKey) {
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

    pub fn store(&self, key: MemberKey, hits: Vec<CompletionHit>) {
        lock(&self.facts).insert(key, hits);
        self.board.members_ready(key.session_id);
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
