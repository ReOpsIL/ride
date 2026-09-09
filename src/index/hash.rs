use std::fs;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};

use crate::skip::skip_dir_name;

pub fn content_hash(root: &Path) -> String {
    let mut files = Vec::new();
    collect(root, root, &mut files);
    files.sort();
    let mut hasher = Sha256::new();
    for (rel, len, mtime) in files {
        hasher.update(rel.as_bytes());
        hasher.update(len.to_le_bytes());
        hasher.update(mtime.to_le_bytes());
    }
    hasher.finalize().iter().fold(String::new(), |mut out, b| {
        use std::fmt::Write;
        let _ = write!(out, "{b:02x}");
        out
    })
}

fn collect(root: &Path, dir: &Path, out: &mut Vec<(String, u64, u128)>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if path.is_dir() {
            if skip_dir_name(&name) {
                continue;
            }
            collect(root, &path, out);
            continue;
        }
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }
        let rel = path
            .strip_prefix(root)
            .unwrap_or(&path)
            .to_string_lossy()
            .replace('\\', "/");
        let meta = fs::metadata(&path).ok();
        let len = meta.as_ref().map(|m| m.len()).unwrap_or(0);
        out.push((rel, len, mtime_nanos(meta.as_ref())));
    }
}

pub fn crate_key(path: &Path) -> PathBuf {
    path.canonicalize().unwrap_or_else(|_| path.to_path_buf())
}

fn mtime_nanos(meta: Option<&fs::Metadata>) -> u128 {
    meta.and_then(|m| m.modified().ok())
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_nanos())
        .unwrap_or(0)
}
