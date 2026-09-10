use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, QueryMode};
use crate::query;

use super::snapshot::Snapshot;
use super::{header_hits, merge};

const CATALOG_MIN_CHARS: usize = 2;

pub fn hits(snap: &Snapshot, q: &CompletionQuery) -> CompletionResponse {
    let limit = if q.limit == 0 { 20 } else { q.limit } as usize;
    let prefix = q.prefix.as_str();
    let mut pool: Vec<CompletionHit> = Vec::new();
    let mut truncated = false;
    if let Some(local) = &snap.local {
        pool.extend(local.hits.iter().cloned());
    }
    if snap.scope().is_some_and(|s| !s.includes.is_empty()) {
        pool.extend(header_hits::completions(snap.headers(), prefix, limit));
    }
    merge::tier_all(&mut pool, prefix);
    pool.extend(query::keyword_hits(
        snap.lang.keywords(),
        prefix,
        limit as u32,
    ));
    if snap.lang.has_catalog() && prefix.chars().count() >= CATALOG_MIN_CHARS {
        let mut cq = q.clone();
        cq.mode = QueryMode::Items;
        cq.current_crate = None;
        cq.current_module = None;
        let mut resp = query::search(snap.catalog.src(), &cq, &snap.catalog.overlay);
        merge::boost_catalog(&mut resp.hits, prefix, &snap.imports);
        truncated |= resp.truncated;
        pool.extend(resp.hits);
    }
    merge::finish(q, pool, truncated)
}
