use std::collections::{HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::highlight::{IncludeRef, SourceScope};

use super::headers::{Header, HeaderCache};

const MAX_FILES: usize = 64;

pub fn reachable(cache: &HeaderCache, scope: &SourceScope) -> Vec<Arc<Header>> {
    let Some(path) = scope.path.as_deref() else {
        return Vec::new();
    };
    let mut seen: HashSet<PathBuf> = HashSet::new();
    seen.extend(path.canonicalize().ok());
    let mut queue = VecDeque::new();
    queue.push_back((dir_of(path), scope.includes.clone()));
    let mut out = Vec::new();
    while let Some((dir, includes)) = queue.pop_front() {
        for include in &includes {
            if out.len() >= MAX_FILES {
                return out;
            }
            let Some(target) = resolve(include, &dir, &scope.search_dirs) else {
                continue;
            };
            if !seen.insert(target.clone()) {
                continue;
            }
            if let Some(header) = cache.load(&target) {
                queue.push_back((dir_of(&header.path), header.summary.includes.clone()));
                out.push(header);
            }
        }
    }
    out
}

fn resolve(include: &IncludeRef, dir: &Path, search: &[PathBuf]) -> Option<PathBuf> {
    let local = include.quoted.then(|| dir.join(&include.name));
    local
        .into_iter()
        .chain(search.iter().map(|d| d.join(&include.name)))
        .find(|p| p.is_file())
        .and_then(|p| p.canonicalize().ok())
}

fn dir_of(path: &Path) -> PathBuf {
    path.parent().map(Path::to_path_buf).unwrap_or_default()
}
