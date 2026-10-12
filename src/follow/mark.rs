use std::sync::atomic::{AtomicU32, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

static TAIL: AtomicU32 = AtomicU32::new(1);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Mark {
    pub id: String,
    pub author: String,
    pub agent: bool,
    pub path: String,
    pub item: String,
    pub kind: String,
    pub mark: String,
    pub note: String,
    pub basis: String,
    pub commit: String,
    pub at: String,
    pub re: String,
    pub accepted: bool,
}

pub fn new_id() -> String {
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let tail = TAIL.fetch_add(1, Ordering::Relaxed);
    format!("{millis:x}{tail:x}")
}

pub fn slug(name: &str) -> Option<String> {
    let cleaned: String = name
        .chars()
        .filter(|c| !matches!(c, '/' | '\\' | '\0'))
        .collect();
    let cleaned = cleaned.trim();
    (!cleaned.is_empty()).then(|| cleaned.to_string())
}

pub fn now_stamp() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("{secs}")
}
