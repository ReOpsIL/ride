use std::collections::{HashMap, VecDeque};
use std::sync::Arc;

use crate::ffi::CompletionHit;

use super::key::MemberKey;

const CAPACITY: usize = 64;

#[derive(Default)]
pub struct Facts {
    members: HashMap<MemberKey, Arc<[CompletionHit]>>,
    order: VecDeque<MemberKey>,
}

impl Facts {
    pub fn members(&self, key: &MemberKey) -> Option<Arc<[CompletionHit]>> {
        self.members.get(key).cloned()
    }

    pub fn insert(&mut self, key: MemberKey, hits: Vec<CompletionHit>) {
        if self.members.insert(key, hits.into()).is_none() {
            self.order.push_back(key);
        }
        while self.order.len() > CAPACITY {
            if let Some(old) = self.order.pop_front() {
                self.members.remove(&old);
            }
        }
    }

    pub fn forget(&mut self, session_id: u64) {
        self.members.retain(|k, _| k.session_id != session_id);
        self.order.retain(|k| k.session_id != session_id);
    }

    pub fn clear(&mut self) {
        self.members.clear();
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
        let keys: Vec<MemberKey> = (0..=CAPACITY)
            .filter_map(|site| MemberKey::new(1, &text, site))
            .collect();
        for key in &keys {
            facts.insert(*key, hit());
        }
        assert!(facts.members(&keys[0]).is_none());
        assert!(facts.members(&keys[CAPACITY]).is_some());
    }

    #[test]
    fn forgetting_a_session_drops_only_its_entries() {
        let mut facts = Facts::default();
        let a = MemberKey::new(1, "a.", 2).expect("key");
        let b = MemberKey::new(2, "a.", 2).expect("key");
        facts.insert(a, hit());
        facts.insert(b, hit());
        facts.forget(1);
        assert!(facts.members(&a).is_none());
        assert!(facts.members(&b).is_some());
    }
}
