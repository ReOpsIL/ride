use std::path::Path;

use crate::ffi::{CompletionQuery, CompletionResponse, QueryMode};
use crate::query::{self, IndexSrc};

use super::Engine;

pub fn run(engine: &Engine, mut q: CompletionQuery) -> CompletionResponse {
    let (kind, prefix) = query::parse_prefix(&q.prefix, q.kind_filter);
    q.kind_filter = kind.or(q.kind_filter);
    q.prefix = prefix;
    let query_id = q.query_id;
    let session_id = q.session_id;
    let snap = engine.write(|i| {
        let prev = i.latest_query_id.get(&session_id).copied().unwrap_or(0);
        if prev > query_id {
            return None;
        }
        i.latest_query_id.insert(session_id, query_id);
        let buffer = if q.mode == QueryMode::BufferLocal {
            i.sessions
                .get(&session_id)
                .map(|s| s.local_hits(&q.prefix, if q.limit == 0 { 20 } else { q.limit }))
                .unwrap_or_default()
        } else {
            Vec::new()
        };
        Some((
            i.config.index_dir.clone(),
            i.overlay.clone(),
            buffer,
            i.index.clone(),
            i.reader.clone(),
        ))
    });
    let Ok(Some((index_dir, overlay, buffer, index, reader))) = snap else {
        return CompletionResponse {
            query_id,
            hits: Vec::new(),
            truncated: false,
        };
    };
    let src = match (index.as_ref(), reader.as_ref()) {
        (Some(index), Some(reader)) => IndexSrc::Live(index, reader),
        _ => IndexSrc::Dir(Path::new(&index_dir)),
    };
    let resp = query::run_query(src, q, buffer, &overlay);
    let current = engine
        .read(|i| i.latest_query_id.get(&session_id).copied())
        .ok()
        .flatten();
    if current != Some(query_id) {
        return CompletionResponse {
            query_id,
            hits: Vec::new(),
            truncated: false,
        };
    }
    resp
}
