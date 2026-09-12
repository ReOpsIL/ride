use std::sync::{Arc, Mutex, Weak};

use crate::debug::registry::DebugRegistry;

struct Entry {
    registry: Weak<DebugRegistry>,
    id: u64,
}

#[derive(Default)]
pub struct Registration {
    slot: Mutex<Option<Entry>>,
}

impl Registration {
    pub fn set(&self, registry: &Arc<DebugRegistry>, id: u64) {
        if let Ok(mut slot) = self.slot.lock() {
            *slot = Some(Entry {
                registry: Arc::downgrade(registry),
                id,
            });
        }
    }

    pub fn retire(&self) {
        let taken = self.slot.lock().ok().and_then(|mut slot| slot.take());
        let Some(entry) = taken else {
            return;
        };
        let Some(registry) = entry.registry.upgrade() else {
            return;
        };
        registry.remove(entry.id);
    }
}
