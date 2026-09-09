use std::collections::HashSet;

use tantivy::TantivyDocument;
use tantivy::collector::TopDocs;
use tantivy::query::RegexQuery;

use crate::ffi::CompletionResponse;

use super::hit::{crate_hit, field_str};
use super::parse::escape_regex;

pub fn crate_prefix(
    reader: &tantivy::IndexReader,
    crate_field: tantivy::schema::Field,
    prefix: &str,
    limit: u32,
    query_id: u64,
) -> CompletionResponse {
    let empty = CompletionResponse {
        query_id,
        hits: Vec::new(),
        truncated: false,
    };
    let pat = format!("{}.*", escape_regex(&prefix.to_ascii_lowercase()));
    let Ok(regex) = RegexQuery::from_pattern(&pat, crate_field) else {
        return empty;
    };
    let searcher = reader.searcher();
    let Ok(top) = searcher.search(
        &regex,
        &TopDocs::with_limit((limit as usize).saturating_mul(8)),
    ) else {
        return empty;
    };
    let mut seen = HashSet::new();
    let mut hits = Vec::new();
    for (score, addr) in top {
        let Ok(doc) = searcher.doc::<TantivyDocument>(addr) else {
            continue;
        };
        let Some(name) = field_str(&doc, crate_field) else {
            continue;
        };
        if !seen.insert(name.clone()) {
            continue;
        }
        hits.push(crate_hit(name, score));
        if hits.len() >= limit as usize {
            break;
        }
    }
    let truncated = hits.len() >= limit as usize;
    CompletionResponse {
        query_id,
        hits,
        truncated,
    }
}
