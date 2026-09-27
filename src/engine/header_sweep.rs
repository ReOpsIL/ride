use std::fs::{self, DirEntry};
use std::path::Path;
use std::thread;
use std::time::{Duration, SystemTime};

use super::Engine;

const MAX_AGE: Duration = Duration::from_secs(30 * 24 * 60 * 60);

impl Engine {
    pub(crate) fn sweep_header_store(&self) {
        let Ok(cache) = self.read(|i| i.headers.clone()) else {
            return;
        };
        let _ = thread::Builder::new()
            .name("ride-header-sweep".into())
            .spawn(move || cache.sweep_store());
    }
}

pub fn sweep(dir: &Path, prefix: &str) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    let now = SystemTime::now();
    for entry in entries.flatten() {
        if expired(&entry, prefix, now) {
            let _ = fs::remove_file(entry.path());
        }
    }
}

fn expired(entry: &DirEntry, prefix: &str, now: SystemTime) -> bool {
    let Ok(meta) = entry.metadata() else {
        return false;
    };
    if !meta.is_file() {
        return false;
    }
    let name = entry.file_name();
    let current = name.to_str().is_some_and(|n| n.starts_with(prefix));
    let old = meta
        .modified()
        .ok()
        .and_then(|t| now.duration_since(t).ok())
        .is_some_and(|age| age > MAX_AGE);
    !current || old
}
