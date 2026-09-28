use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use super::job::DocText;
use super::roots::Roots;
use super::server::Server;
use super::shared::lock;
use super::sidecar::Sidecar;

pub type Key = (Server, PathBuf);

#[derive(Default)]
pub struct Fleet {
    sidecars: Mutex<HashMap<Key, Arc<Sidecar>>>,
    roots: Mutex<Roots>,
}

impl Fleet {
    pub fn key_for(&self, doc: &DocText) -> Option<Key> {
        let server = Server::for_lang(doc.lang)?;
        let root = lock(&self.roots).of(server, &doc.path)?;
        Some((server, root))
    }

    pub fn get(&self, key: &Key) -> Option<Arc<Sidecar>> {
        lock(&self.sidecars).get(key).cloned()
    }

    pub fn insert(&self, key: Key, sidecar: Arc<Sidecar>) {
        lock(&self.sidecars).insert(key, sidecar);
    }

    pub fn remove(&self, key: &Key) -> Option<Arc<Sidecar>> {
        lock(&self.sidecars).remove(key)
    }

    pub fn clear(&self) {
        lock(&self.sidecars).clear();
    }

    pub fn close(&self, session_id: u64) {
        let sidecars: Vec<Arc<Sidecar>> = lock(&self.sidecars).values().cloned().collect();
        for sidecar in sidecars {
            sidecar.close(session_id);
        }
    }
}
