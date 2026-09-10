use std::path::{Path, PathBuf};

use super::listing::Entry;

const SUFFIX: &str = ".framework";
const HEADERS: &str = "Headers";

pub fn headers_dir(root: &Path, sub_dir: &str) -> Option<PathBuf> {
    let (framework, rest) = sub_dir.split_once('/').unwrap_or((sub_dir, ""));
    if framework.is_empty() {
        return None;
    }
    let mut dir = root.join(format!("{framework}{SUFFIX}")).join(HEADERS);
    if !rest.is_empty() {
        dir.push(rest);
    }
    Some(dir)
}

pub fn name_of(entry: &Entry) -> Option<&str> {
    entry
        .is_dir
        .then(|| entry.name.strip_suffix(SUFFIX))
        .flatten()
}

pub fn headers_of(entry: &Entry) -> PathBuf {
    entry.path.join(HEADERS)
}
