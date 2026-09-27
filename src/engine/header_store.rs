use std::fs::{self, Metadata};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use sha2::{Digest, Sha256};

use crate::highlight::FileSummary;

use super::header_sweep;

const FORMAT: &str = "header-summary-v2";
const REFRESH_AFTER: Duration = Duration::from_secs(24 * 60 * 60);

pub struct HeaderStore {
    dir: PathBuf,
}

impl HeaderStore {
    pub fn new(dir: PathBuf) -> Self {
        Self { dir }
    }

    pub fn read(&self, path: &Path, meta: &Metadata) -> Option<FileSummary> {
        let file = self.file(path, meta);
        let bytes = fs::read(&file).ok()?;
        let summary = serde_json::from_slice(&bytes).ok()?;
        refresh(&file);
        Some(summary)
    }

    pub fn write(&self, path: &Path, meta: &Metadata, summary: &FileSummary) {
        let Ok(json) = serde_json::to_vec(summary) else {
            return;
        };
        if fs::create_dir_all(&self.dir).is_err() {
            return;
        }
        let target = self.file(path, meta);
        let tmp = target.with_extension(format!("tmp{}", std::process::id()));
        if fs::write(&tmp, json).is_ok() && fs::rename(&tmp, &target).is_err() {
            let _ = fs::remove_file(&tmp);
        }
    }

    pub fn sweep(&self) {
        header_sweep::sweep(&self.dir, &prefix());
    }

    fn file(&self, path: &Path, meta: &Metadata) -> PathBuf {
        let mtime = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let mut hasher = Sha256::new();
        hasher.update(FORMAT.as_bytes());
        hasher.update(path.to_string_lossy().as_bytes());
        hasher.update(mtime.to_le_bytes());
        hasher.update(meta.len().to_le_bytes());
        let digest = hasher.finalize();
        let hex: String = digest[..16].iter().map(|b| format!("{b:02x}")).collect();
        self.dir.join(format!("{}{hex}.json", prefix()))
    }
}

fn prefix() -> String {
    format!("{FORMAT}-")
}

fn refresh(file: &Path) {
    let now = SystemTime::now();
    let stale = fs::metadata(file)
        .and_then(|m| m.modified())
        .is_ok_and(|t| now.duration_since(t).is_ok_and(|age| age > REFRESH_AFTER));
    if stale && let Ok(handle) = fs::File::options().write(true).open(file) {
        let _ = handle.set_modified(now);
    }
}
