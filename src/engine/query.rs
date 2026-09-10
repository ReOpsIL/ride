use std::path::Path;
use std::sync::Arc;

use crate::ffi::{
    CompletionContext, CompletionHit, CompletionQuery, CompletionResponse, QueryMode,
};
use crate::highlight::{Lang, LocalHits, LocalQuery, SourceScope};
use crate::query::{self, IndexSrc};

use super::headers::HeaderCache;
use super::{Engine, header_hits, include_graph};

pub fn run(engine: &Engine, mut q: CompletionQuery) -> CompletionResponse {
    let (kind, prefix) = query::parse_prefix(&q.prefix, q.kind_filter);
    q.kind_filter = kind.or(q.kind_filter);
    q.prefix = prefix;
    let query_id = q.query_id;
    let session_id = q.session_id;
    let limit = if q.limit == 0 { 20 } else { q.limit };
    let snap = engine.write(|i| {
        let prev = i.latest_query_id.get(&session_id).copied().unwrap_or(0);
        if prev > query_id {
            return None;
        }
        i.latest_query_id.insert(session_id, query_id);
        let session = i.sessions.get(&session_id);
        let lang = session.map(|s| s.lang()).unwrap_or(Lang::Rust);
        if !lang.has_catalog() {
            q.mode = QueryMode::BufferLocal;
        }
        let local = session
            .filter(|_| q.mode == QueryMode::BufferLocal)
            .map(|s| {
                let hits = s.local_hits(&LocalQuery {
                    prefix: &q.prefix,
                    limit,
                    at: q.replace_start_byte,
                });
                (hits, s.scope())
            });
        Some((
            i.config.index_dir.clone(),
            i.overlay.clone(),
            lang,
            local,
            i.headers.clone(),
            i.index.clone(),
            i.reader.clone(),
        ))
    });
    let Ok(Some((index_dir, overlay, lang, local, headers, index, reader))) = snap else {
        return empty(query_id);
    };
    let buffer = match local {
        Some((hits, scope)) => merge_headers(&mut q, hits, &scope, &headers, limit as usize),
        None => Vec::new(),
    };
    let src = match (index.as_ref(), reader.as_ref()) {
        (Some(index), Some(reader)) => IndexSrc::Live(index, reader),
        _ => IndexSrc::Dir(Path::new(&index_dir)),
    };
    let resp = query::run_query(src, q, lang, buffer, &overlay);
    let current = engine
        .read(|i| i.latest_query_id.get(&session_id).copied())
        .ok()
        .flatten();
    if current != Some(query_id) {
        return empty(query_id);
    }
    resp
}

fn merge_headers(
    q: &mut CompletionQuery,
    local: LocalHits,
    scope: &SourceScope,
    cache: &Arc<HeaderCache>,
    limit: usize,
) -> Vec<CompletionHit> {
    let Some(access) = local.access else {
        let mut hits = local.hits;
        if !scope.includes.is_empty() {
            let headers = include_graph::reachable(cache, scope);
            hits.extend(header_hits::completions(&headers, &q.prefix, limit));
            hits.sort_by(|a, b| b.score.total_cmp(&a.score));
        }
        return hits;
    };
    q.context = CompletionContext::MemberAccess;
    let Some(type_name) = access.type_name else {
        return local.hits;
    };
    let headers = include_graph::reachable(cache, scope);
    let members = header_hits::members(&scope.types, &headers, &type_name, &q.prefix, limit);
    if members.is_empty() {
        local.hits
    } else {
        members
    }
}

fn empty(query_id: u64) -> CompletionResponse {
    CompletionResponse {
        query_id,
        hits: Vec::new(),
        truncated: false,
    }
}
