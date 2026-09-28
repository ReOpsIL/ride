use std::collections::{HashMap, VecDeque};
use std::sync::Arc;

use crate::ffi::CompletionHit;

use super::key::SiteKey;

const CAPACITY: usize = 64;

#[derive(Default)]
pub struct Facts {
    entries: HashMap<SiteKey, Arc<[CompletionHit]>>,
    order: VecDeque<SiteKey>,
}

impl Facts {
    pub fn hits(&self, key: &SiteKey) -> Option<Arc<[CompletionHit]>> {
        self.entries.get(key).cloned()
    }

    pub fn insert(&mut self, key: SiteKey, hits: Vec<CompletionHit>) {
        if self.entries.insert(key, hits.into()).is_none() {
            self.order.push_back(key);
        }
        while self.order.len() > CAPACITY {
            if let Some(old) = self.order.pop_front() {
                self.entries.remove(&old);
            }
        }
    }

    pub fn forget(&mut self, session_id: u64) {
        self.entries.retain(|k, _| k.session_id != session_id);
        self.order.retain(|k| k.session_id != session_id);
    }

    pub fn clear(&mut self) {
        self.entries.clear();
        self.order.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::ItemKind;

    fn hit() -> Vec<CompletionHit> {
        vec![CompletionHit::local("len", ItemKind::Method, 1.0, None)]
    }

    #[test]
    fn the_oldest_entry_goes_first() {
        let mut facts = Facts::default();
        let text = "x".repeat(CAPACITY + 1);
        let keys: Vec<SiteKey> = (0..=CAPACITY)
            .filter_map(|site| SiteKey::new(1, &text, site))
            .collect();
        for key in &keys {
            facts.insert(*key, hit());
        }
        assert!(facts.hits(&keys[0]).is_none());
        assert!(facts.hits(&keys[CAPACITY]).is_some());
    }

    #[test]
    fn forgetting_a_session_drops_only_its_entries() {
        let mut facts = Facts::default();
        let a = SiteKey::new(1, "a.", 2).expect("key");
        let b = SiteKey::new(2, "a.", 2).expect("key");
        facts.insert(a, hit());
        facts.insert(b, hit());
        facts.forget(1);
        assert!(facts.hits(&a).is_none());
        assert!(facts.hits(&b).is_some());
    }
}
