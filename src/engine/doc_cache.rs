use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::SystemTime;

use super::doc_block::Lifted;

struct Slot {
    mtime: Option<SystemTime>,
    lifted: Option<Lifted>,
}

pub fn cached(path: &str, name: &str, load: impl FnOnce() -> Option<Lifted>) -> Option<Lifted> {
    if path.is_empty() || name.is_empty() {
        return load();
    }
    let mtime = std::fs::metadata(path).and_then(|m| m.modified()).ok();
    let key = (path.to_string(), name.to_string());
    if let Some(slot) = lock().get(&key)
        && slot.mtime == mtime
    {
        return slot.lifted.clone();
    }
    let lifted = load();
    lock().insert(
        key,
        Slot {
            mtime,
            lifted: lifted.clone(),
        },
    );
    lifted
}

fn lock() -> std::sync::MutexGuard<'static, HashMap<(String, String), Slot>> {
    static MAP: OnceLock<Mutex<HashMap<(String, String), Slot>>> = OnceLock::new();
    MAP.get_or_init(|| Mutex::new(HashMap::new()))
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}
