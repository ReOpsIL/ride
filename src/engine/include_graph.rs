use std::collections::{HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::highlight::{IncludeRef, SourceScope};

use super::headers::{Header, HeaderCache};

const MAX_PROJECT: usize = 64;
const MAX_SYSTEM: usize = 512;

pub fn reachable(cache: &HeaderCache, scope: &SourceScope, system: &[PathBuf]) -> Vec<Arc<Header>> {
    let Some(path) = scope.path.as_deref() else {
        return Vec::new();
    };
    let mut seen: HashSet<PathBuf> = HashSet::new();
    seen.extend(path.canonicalize().ok());
    let mut queue = VecDeque::new();
    queue.push_back((dir_of(path), scope.includes.clone()));
    let mut out = Vec::new();
    let mut counts = (0usize, 0usize);
    while let Some((dir, includes)) = queue.pop_front() {
        for include in &includes {
            if counts.0 >= MAX_PROJECT && counts.1 >= MAX_SYSTEM {
                return out;
            }
            let Some((target, is_system)) = resolve(include, &dir, &scope.search_dirs, system)
            else {
                continue;
            };
            let count = if is_system {
                &mut counts.1
            } else {
                &mut counts.0
            };
            let cap = if is_system { MAX_SYSTEM } else { MAX_PROJECT };
            if *count >= cap || !seen.insert(target.clone()) {
                continue;
            }
            let loaded = if is_system {
                cache.load_system(&target)
            } else {
                cache.load(&target)
            };
            if let Some(header) = loaded {
                *count += 1;
                queue.push_back((dir_of(&header.path), header.summary.includes.clone()));
                out.push(header);
            }
        }
    }
    out
}

fn resolve(
    include: &IncludeRef,
    dir: &Path,
    search: &[PathBuf],
    system: &[PathBuf],
) -> Option<(PathBuf, bool)> {
    let local = include.quoted.then(|| dir.join(&include.name));
    local
        .into_iter()
        .chain(search.iter().map(|d| d.join(&include.name)))
        .map(|p| (p, false))
        .chain(system.iter().map(|d| (d.join(&include.name), true)))
        .find(|(p, _)| p.is_file())
        .and_then(|(p, is_system)| Some((p.canonicalize().ok()?, is_system)))
}

fn dir_of(path: &Path) -> PathBuf {
    path.parent().map(Path::to_path_buf).unwrap_or_default()
}
