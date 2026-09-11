use std::path::{Path, PathBuf};

use crate::engine::headers::HeaderCache;
use crate::engine::include_graph;
use crate::highlight::{SourceScope, summarize};

use super::compile_db;
use super::include_dirs;

pub fn sources_including(header: &Path) -> Vec<PathBuf> {
    let Ok(header) = header.canonicalize() else {
        return Vec::new();
    };
    let cache = HeaderCache::new(None);
    compile_db::sources_near(&header)
        .into_iter()
        .filter(|src| reaches(&cache, src, &header))
        .collect()
}

fn reaches(cache: &HeaderCache, src: &Path, header: &Path) -> bool {
    let Some(scope) = scope_of(src) else {
        return false;
    };
    include_graph::reachable(cache, &scope, &[])
        .iter()
        .any(|h| h.path == *header)
}

fn scope_of(src: &Path) -> Option<SourceScope> {
    let text = std::fs::read_to_string(src).ok()?;
    let summary = summarize(src, &text).ok()?;
    Some(SourceScope {
        path: Some(src.to_path_buf()),
        search_dirs: include_dirs(src),
        includes: summary.includes,
        types: summary.types,
    })
}
