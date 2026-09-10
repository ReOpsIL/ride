use std::collections::HashMap;
use std::fs::DirEntry;
use std::path::{Path, PathBuf};
use std::sync::{Arc, LazyLock, Mutex};
use std::time::SystemTime;

const MAX_ENTRIES: usize = 4000;
const HEADER_EXTENSIONS: &[&str] = &["h", "hh", "hpp", "hxx", "h++", "inl", "ipp", "tpp", "inc"];

#[derive(Debug, Clone)]
pub struct Entry {
    pub name: String,
    pub is_dir: bool,
    pub path: PathBuf,
}

type Listing = Arc<Vec<Entry>>;

#[derive(Default)]
pub struct DirCache {
    entries: Mutex<HashMap<PathBuf, (SystemTime, Listing)>>,
}

static CACHE: LazyLock<DirCache> = LazyLock::new(DirCache::default);

pub fn list(dir: &Path) -> Option<Listing> {
    CACHE.list(dir)
}

impl DirCache {
    fn list(&self, dir: &Path) -> Option<Listing> {
        let modified = std::fs::metadata(dir).ok()?.modified().ok()?;
        if let Some(cached) = self.cached(dir, modified) {
            return Some(cached);
        }
        let listing = Arc::new(read(dir)?);
        if let Ok(mut entries) = self.entries.lock() {
            entries.insert(dir.to_path_buf(), (modified, listing.clone()));
        }
        Some(listing)
    }

    fn cached(&self, dir: &Path, modified: SystemTime) -> Option<Listing> {
        let entries = self.entries.lock().ok()?;
        let (stamp, listing) = entries.get(dir)?;
        (*stamp == modified).then(|| listing.clone())
    }
}

fn read(dir: &Path) -> Option<Vec<Entry>> {
    let mut out: Vec<Entry> = std::fs::read_dir(dir)
        .ok()?
        .take(MAX_ENTRIES)
        .flatten()
        .filter_map(entry_of)
        .collect();
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Some(out)
}

fn entry_of(entry: DirEntry) -> Option<Entry> {
    let name = entry.file_name().into_string().ok()?;
    if name.starts_with('.') {
        return None;
    }
    let file_type = entry.file_type().ok()?;
    let path = entry.path();
    let is_dir = file_type.is_dir() || (file_type.is_symlink() && path.is_dir());
    if !is_dir && !is_header_name(&name) {
        return None;
    }
    Some(Entry { name, is_dir, path })
}

fn is_header_name(name: &str) -> bool {
    match name.rsplit_once('.') {
        Some((_, ext)) => HEADER_EXTENSIONS.contains(&ext.to_ascii_lowercase().as_str()),
        None => true,
    }
}
