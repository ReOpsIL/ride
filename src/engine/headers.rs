use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use crate::highlight::{FileSummary, summarize};

const MAX_BYTES: u64 = 4 * 1024 * 1024;

pub struct Header {
    pub path: PathBuf,
    modified: Option<SystemTime>,
    pub summary: FileSummary,
}

#[derive(Default)]
pub struct HeaderCache {
    entries: Mutex<HashMap<PathBuf, Arc<Header>>>,
}

impl HeaderCache {
    pub fn load(&self, path: &Path) -> Option<Arc<Header>> {
        let meta = std::fs::metadata(path).ok()?;
        if !meta.is_file() || meta.len() > MAX_BYTES {
            return None;
        }
        let modified = meta.modified().ok();
        if let Some(cached) = self.cached(path)
            && cached.modified == modified
        {
            return Some(cached);
        }
        let text = std::fs::read_to_string(path).ok()?;
        let summary = summarize(path, &text).ok()?;
        let header = Arc::new(Header {
            path: path.to_path_buf(),
            modified,
            summary,
        });
        if let Ok(mut entries) = self.entries.lock() {
            entries.insert(path.to_path_buf(), header.clone());
        }
        Some(header)
    }

    fn cached(&self, path: &Path) -> Option<Arc<Header>> {
        self.entries.lock().ok()?.get(path).cloned()
    }
}
