use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, QueryMode};
use crate::query;

use super::snapshot::Snapshot;
use super::{header_hits, merge, oracle_hits};

const CATALOG_MIN_CHARS: usize = 2;

pub fn hits(snap: &Snapshot, q: &CompletionQuery) -> CompletionResponse {
    if let Some(known) = &snap.oracle_hits {
        let mut pool = oracle_hits::in_scope(known, q, snap.next_char());
        let (extras, truncated) = catalog_and_keywords(snap, q);
        oracle_hits::add_missing(&mut pool, extras);
        return merge::finish(q, pool, truncated);
    }
    let limit = q.limit_or_default() as usize;
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
    let (extras, more) = catalog_and_keywords(snap, q);
    pool.extend(extras);
    truncated |= more;
    merge::finish(q, pool, truncated)
}

fn catalog_and_keywords(snap: &Snapshot, q: &CompletionQuery) -> (Vec<CompletionHit>, bool) {
    let prefix = q.prefix.as_str();
    let mut pool = query::keyword_hits(snap.lang.keywords(), prefix, q.limit_or_default());
    if !snap.lang.has_catalog() || prefix.chars().count() < CATALOG_MIN_CHARS {
        return (pool, false);
    }
    let mut cq = q.clone();
    cq.mode = QueryMode::Items;
    cq.current_crate = None;
    cq.current_module = None;
    let mut resp = snap.catalog.search(&cq);
    merge::boost_catalog(&mut resp.hits, prefix, &snap.imports);
    pool.extend(resp.hits);
    (pool, resp.truncated)
}
