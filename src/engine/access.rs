use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse};
use crate::highlight::TypeTable;

use super::snapshot::Snapshot;
use super::{header_hits, merge, oracle_members, rust_members};

pub fn hits(snap: &Snapshot, q: &CompletionQuery) -> CompletionResponse {
    if let Some(members) = &snap.oracle_members {
        let next_char = snap.site.as_ref().and_then(|s| s.next_char);
        return oracle_members::hits(members, q, next_char);
    }
    if let Some(resp) = rust_members::try_hits(snap, q) {
        return resp;
    }
    let limit = q.limit_or_default() as usize;
    let Some(local) = &snap.local else {
        return CompletionResponse::empty(q.query_id);
    };
    let mut pool: Vec<CompletionHit> = resolved_members(snap, q, limit)
        .filter(|members| !members.is_empty())
        .unwrap_or_else(|| local.hits.clone());
    merge::keep_order(&mut pool, &q.prefix);
    merge::finish(q, pool, false)
}

fn resolved_members(
    snap: &Snapshot,
    q: &CompletionQuery,
    limit: usize,
) -> Option<Vec<CompletionHit>> {
    let chain = snap.local.as_ref()?.access.as_ref()?.chain.as_ref()?;
    let scope = snap.scope()?;
    let headers = snap.headers();
    let tables = header_hits::tables(&scope.types, headers);
    let type_name = TypeTable::follow(&tables, chain)?;
    Some(header_hits::members(&tables, &type_name, &q.prefix, limit))
}
