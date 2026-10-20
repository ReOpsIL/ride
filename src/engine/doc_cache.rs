use std::collections::{HashMap, VecDeque};
use std::sync::{Mutex, MutexGuard, OnceLock};
use std::time::SystemTime;

use super::doc_block::Lifted;

const CAPACITY: usize = 512;

#[derive(Clone, PartialEq, Eq, Hash)]
struct Key {
    path: String,
    byte: usize,
    name: String,
}

struct Slot {
    mtime: Option<SystemTime>,
    lifted: Option<Lifted>,
}

#[derive(Default)]
struct Cache {
    slots: HashMap<Key, Slot>,
    order: VecDeque<Key>,
}

impl Cache {
    fn get(&self, key: &Key, mtime: Option<SystemTime>) -> Option<Option<Lifted>> {
        self.slots
            .get(key)
            .filter(|slot| slot.mtime == mtime)
            .map(|slot| slot.lifted.clone())
    }

    fn put(&mut self, key: Key, slot: Slot) {
        if self.slots.insert(key.clone(), slot).is_none() {
            self.order.push_back(key);
        }
        while self.order.len() > CAPACITY {
            if let Some(old) = self.order.pop_front() {
                self.slots.remove(&old);
            }
        }
    }
}

pub fn cached(
    path: &str,
    byte: usize,
    name: &str,
    load: impl FnOnce() -> Option<Lifted>,
) -> Option<Lifted> {
    if path.is_empty() || name.is_empty() {
        return load();
    }
    let mtime = std::fs::metadata(path).and_then(|m| m.modified()).ok();
    let key = Key {
        path: path.to_string(),
        byte,
        name: name.to_string(),
    };
    if let Some(hit) = lock().get(&key, mtime) {
        return hit;
    }
    let lifted = load();
    lock().put(
        key,
        Slot {
            mtime,
            lifted: lifted.clone(),
        },
    );
    lifted
}

fn lock() -> MutexGuard<'static, Cache> {
    static CACHE: OnceLock<Mutex<Cache>> = OnceLock::new();
    CACHE
        .get_or_init(Mutex::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lifted(markdown: &str) -> Option<Lifted> {
        Some(Lifted {
            markdown: markdown.to_string(),
            start_byte: 0,
        })
    }

    #[test]
    fn two_items_with_one_name_in_one_file_stay_apart() {
        let dir = tempfile::tempdir().expect("tempdir");
        let file = dir.path().join("cell.rs");
        std::fs::write(&file, "x").expect("write");
        let path = file.display().to_string();
        let first = cached(&path, 10, "new", || lifted("Cell"));
        let second = cached(&path, 90, "new", || lifted("RefCell"));
        assert_eq!(first.map(|l| l.markdown).as_deref(), Some("Cell"));
        assert_eq!(second.map(|l| l.markdown).as_deref(), Some("RefCell"));
        let again = cached(&path, 10, "new", || lifted("reloaded"));
        assert_eq!(again.map(|l| l.markdown).as_deref(), Some("Cell"));
    }

    #[test]
    fn the_oldest_entry_leaves_past_capacity() {
        let mut cache = Cache::default();
        let key = |byte| Key {
            path: "p".into(),
            byte,
            name: "n".into(),
        };
        for byte in 0..=CAPACITY {
            cache.put(
                key(byte),
                Slot {
                    mtime: None,
                    lifted: None,
                },
            );
        }
        assert_eq!(cache.slots.len(), CAPACITY);
        assert!(cache.get(&key(0), None).is_none());
        assert!(cache.get(&key(CAPACITY), None).is_some());
    }
}
