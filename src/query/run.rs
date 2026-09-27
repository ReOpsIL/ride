use std::collections::HashSet;

use crate::ffi::{
    CompletionContext, CompletionHit, CompletionQuery, CompletionResponse, QueryMode,
};
use crate::highlight::Lang;

use super::keywords::keyword_hits;
use super::parse::parse_prefix;
use super::search::search_open;
use super::source::IndexSrc;

pub fn search(
    src: IndexSrc<'_>,
    q: &CompletionQuery,
    overlay: &HashSet<String>,
) -> CompletionResponse {
    src.with(CompletionResponse::empty(q.query_id), |index, reader| {
        search_open(index, reader, q, overlay)
    })
}

pub fn run_query(
    src: IndexSrc<'_>,
    mut q: CompletionQuery,
    lang: Lang,
    buffer_hits: Vec<CompletionHit>,
    overlay: &HashSet<String>,
) -> CompletionResponse {
    let (kind, prefix) = parse_prefix(&q.prefix, q.kind_filter);
    q.kind_filter = kind.or(q.kind_filter);
    q.prefix = prefix;
    let limit = q.limit_or_default();
    let keywords = lang.keywords();
    match q.mode {
        QueryMode::BufferLocal => {
            let extra = keywords_for(&q, keywords, limit);
            merged(q.query_id, buffer_hits, extra, limit, false)
        }
        QueryMode::Items => {
            let resp = search(src, &q, overlay);
            let kw = keywords_for(&q, keywords, 8);
            merged(q.query_id, kw, resp.hits, limit, resp.truncated)
        }
        QueryMode::PrefixCrates | QueryMode::Phrase => search(src, &q, overlay),
    }
}

fn merged(
    query_id: u64,
    mut hits: Vec<CompletionHit>,
    extra: Vec<CompletionHit>,
    limit: u32,
    truncated: bool,
) -> CompletionResponse {
    hits.extend(extra);
    let mut seen = HashSet::new();
    hits.retain(|h| seen.insert(h.name.clone()));
    hits.sort_by(|a, b| b.score.total_cmp(&a.score));
    let truncated = truncated || hits.len() > limit as usize;
    hits.truncate(limit as usize);
    CompletionResponse::new(query_id, hits, truncated)
}

fn keywords_for(q: &CompletionQuery, keywords: &[&str], limit: u32) -> Vec<CompletionHit> {
    if q.context == CompletionContext::MemberAccess {
        return Vec::new();
    }
    keyword_hits(keywords, &q.prefix, limit)
}
