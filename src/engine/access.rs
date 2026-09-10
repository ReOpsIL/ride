use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse};

use super::snapshot::Snapshot;
use super::{header_hits, include_graph, merge, rust_members};

pub fn hits(snap: &Snapshot, q: &CompletionQuery) -> CompletionResponse {
    let limit = if q.limit == 0 { 20 } else { q.limit } as usize;
    if let Some(resp) = rust_members::try_hits(snap, q) {
        return resp;
    }
    let Some(local) = &snap.local else {
        return CompletionResponse::empty(q.query_id);
    };
    let mut pool: Vec<CompletionHit> = match (&local.access, &snap.scope) {
        (Some(access), Some(scope)) => match &access.type_name {
            Some(type_name) => {
                let headers = include_graph::reachable(&snap.headers, scope);
                let members =
                    header_hits::members(&scope.types, &headers, type_name, &q.prefix, limit);
                if members.is_empty() {
                    local.hits.clone()
                } else {
                    members
                }
            }
            None => local.hits.clone(),
        },
        _ => local.hits.clone(),
    };
    merge::keep_order(&mut pool, &q.prefix);
    merge::finish(q, pool, false)
}
