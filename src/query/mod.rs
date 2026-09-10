use std::collections::HashSet;
use std::path::Path;

use tantivy::{Index, IndexReader};

use crate::ffi::{
    CompletionContext, CompletionHit, CompletionQuery, CompletionResponse, QueryMode,
};
use crate::highlight::Lang;

mod children;
mod collect;
mod exact;
mod hit;
mod items;
mod keywords;
mod parse;
mod rank;
mod search;

pub use children::{Filter, children, listed};
pub use exact::exact_search;
pub use keywords::keyword_hits;
pub use parse::parse_prefix;
pub use search::{search_index, search_open};

pub fn search(
    src: IndexSrc<'_>,
    q: &CompletionQuery,
    overlay: &HashSet<String>,
) -> CompletionResponse {
    match src {
        IndexSrc::Dir(dir) => search_index(dir, q, overlay),
        IndexSrc::Live(index, reader) => search_open(index, reader, q, overlay),
    }
}

pub enum IndexSrc<'a> {
    Dir(&'a Path),
    Live(&'a Index, &'a IndexReader),
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
    let limit = if q.limit == 0 { 20 } else { q.limit };
    let keywords = lang.keywords();
    match q.mode {
        QueryMode::BufferLocal => merge_buffer(&q, keywords, buffer_hits, limit),
        QueryMode::PrefixCrates | QueryMode::Items | QueryMode::Phrase => {
            let mut resp = match src {
                IndexSrc::Dir(dir) => search_index(dir, &q, overlay),
                IndexSrc::Live(index, reader) => search_open(index, reader, &q, overlay),
            };
            if q.mode == QueryMode::Items {
                let mut kw = keywords_for(&q, keywords, 8);
                kw.extend(resp.hits);
                unique_by_name(&mut kw);
                kw.sort_by(|a, b| {
                    b.score
                        .partial_cmp(&a.score)
                        .unwrap_or(std::cmp::Ordering::Equal)
                });
                let truncated = kw.len() as u32 > limit || resp.truncated;
                kw.truncate(limit as usize);
                resp.hits = kw;
                resp.truncated = truncated;
            }
            resp
        }
    }
}

fn merge_buffer(
    q: &CompletionQuery,
    keywords: &[&str],
    extra: Vec<CompletionHit>,
    limit: u32,
) -> CompletionResponse {
    let mut hits = extra;
    hits.extend(keywords_for(q, keywords, limit));
    unique_by_name(&mut hits);
    hits.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let truncated = hits.len() as u32 > limit;
    hits.truncate(limit as usize);
    CompletionResponse::new(q.query_id, hits, truncated)
}

fn unique_by_name(hits: &mut Vec<CompletionHit>) {
    let mut seen = HashSet::new();
    hits.retain(|h| seen.insert(h.name.clone()));
}

fn keywords_for(q: &CompletionQuery, keywords: &[&str], limit: u32) -> Vec<CompletionHit> {
    if q.context == CompletionContext::MemberAccess {
        return Vec::new();
    }
    keywords::keyword_hits(keywords, &q.prefix, limit)
}
