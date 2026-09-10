use std::fs::{self, Metadata};
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

use sha2::{Digest, Sha256};

use crate::highlight::FileSummary;

const FORMAT: &str = "header-summary-v1";

pub struct HeaderStore {
    dir: PathBuf,
}

impl HeaderStore {
    pub fn new(dir: PathBuf) -> Self {
        Self { dir }
    }

    pub fn read(&self, path: &Path, meta: &Metadata) -> Option<FileSummary> {
        let bytes = fs::read(self.file(path, meta)).ok()?;
        serde_json::from_slice(&bytes).ok()
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
        self.dir.join(format!("{hex}.json"))
    }
}
