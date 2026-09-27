use std::fs;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};

use crate::digest::hex;
use crate::files::files_under;
use crate::skip::skip_dir_name;

pub fn content_hash(root: &Path) -> String {
    let mut files: Vec<(String, u64, u128)> = files_under(root, skip_dir_name)
        .into_iter()
        .filter(|path| hashed_file(path))
        .map(|path| stamp(root, &path))
        .collect();
    files.sort();
    let mut hasher = Sha256::new();
    for (rel, len, mtime) in files {
        hasher.update(rel.as_bytes());
        hasher.update(len.to_le_bytes());
        hasher.update(mtime.to_le_bytes());
    }
    hex(&hasher.finalize())
}

fn stamp(root: &Path, path: &Path) -> (String, u64, u128) {
    let rel = path
        .strip_prefix(root)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/");
    let meta = fs::metadata(path).ok();
    let len = meta.as_ref().map(|m| m.len()).unwrap_or(0);
    (rel, len, mtime_nanos(meta.as_ref()))
}

fn hashed_file(path: &Path) -> bool {
    path.file_name().is_some_and(|n| n == "Cargo.toml")
        || path.extension().and_then(|e| e.to_str()) == Some("rs")
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
