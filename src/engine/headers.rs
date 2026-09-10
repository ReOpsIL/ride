use std::collections::HashMap;
use std::fs::Metadata;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use crate::highlight::{FileSummary, scrub_macros, summarize, summarize_header};

use super::header_store::HeaderStore;

const MAX_BYTES: u64 = 4 * 1024 * 1024;

pub struct Header {
    pub path: PathBuf,
    pub system: bool,
    modified: Option<SystemTime>,
    pub summary: FileSummary,
}

pub struct HeaderCache {
    entries: Mutex<HashMap<PathBuf, Arc<Header>>>,
    store: Option<HeaderStore>,
}

impl HeaderCache {
    pub fn new(store_dir: Option<PathBuf>) -> Self {
        Self {
            entries: Mutex::new(HashMap::new()),
            store: store_dir.map(HeaderStore::new),
        }
    }

    pub fn load(&self, path: &Path) -> Option<Arc<Header>> {
        self.load_with(path, false)
    }

    pub fn load_system(&self, path: &Path) -> Option<Arc<Header>> {
        self.load_with(path, true)
    }

    fn load_with(&self, path: &Path, system: bool) -> Option<Arc<Header>> {
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
        let summary = if system {
            self.system_summary(path, &meta)?
        } else {
            summarize(path, &std::fs::read_to_string(path).ok()?).ok()?
        };
        let header = Arc::new(Header {
            path: path.to_path_buf(),
            system,
            modified,
            summary,
        });
        if let Ok(mut entries) = self.entries.lock() {
            entries.insert(path.to_path_buf(), header.clone());
        }
        Some(header)
    }

    fn system_summary(&self, path: &Path, meta: &Metadata) -> Option<FileSummary> {
        if let Some(stored) = self.store.as_ref().and_then(|s| s.read(path, meta)) {
            return Some(stored);
        }
        let text = std::fs::read_to_string(path).ok()?;
        let summary = summarize_header(path, &scrub_macros(&text)).ok()?;
        if let Some(store) = &self.store {
            store.write(path, meta, &summary);
        }
        Some(summary)
    }

    fn cached(&self, path: &Path) -> Option<Arc<Header>> {
        self.entries.lock().ok()?.get(path).cloned()
    }
}
