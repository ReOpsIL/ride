use std::path::PathBuf;

use crate::ffi::{CompletionQuery, CompletionResponse};
use crate::includes::{IncludeRequest, complete};

use super::merge;
use super::snapshot::Snapshot;

pub fn hits(snap: &Snapshot, q: &CompletionQuery, quoted: bool, dir: &str) -> CompletionResponse {
    let limit = if q.limit == 0 { 20 } else { q.limit } as usize;
    let Some(scope) = snap.scope.as_ref() else {
        return CompletionResponse::empty(q.query_id);
    };
    let system: Vec<(PathBuf, bool)> = snap
        .lang
        .clang_name()
        .map(|lang| snap.system_includes.dirs_ranked(lang, &[]))
        .unwrap_or_default();
    let typed = format!("{dir}{}", q.prefix);
    let hits = complete(&IncludeRequest {
        quoted,
        typed: &typed,
        file: scope.path.as_deref(),
        search_dirs: &scope.search_dirs,
        system_dirs: &system,
        limit,
    });
    merge::finish(q, hits, false)
}
