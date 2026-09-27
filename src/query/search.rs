use std::collections::HashSet;

use tantivy::{Index, IndexReader};

use crate::ffi::{CompletionQuery, CompletionResponse, ItemKind, QueryMode};

use super::items::item_search;

pub(super) fn search_open(
    index: &Index,
    reader: &IndexReader,
    q: &CompletionQuery,
    overlay: &HashSet<String>,
) -> CompletionResponse {
    let empty = empty_resp(q.query_id);
    let schema = index.schema();
    let prefix = q.prefix.trim();
    if prefix.is_empty() {
        return empty;
    }
    let limit = q.limit_or_default();
    match q.mode {
        QueryMode::PrefixCrates => {
            let mut crates = q.clone();
            crates.kind_filter = Some(ItemKind::Crate);
            item_search(index, reader, &schema, &crates, prefix, limit)
        }
        QueryMode::Items | QueryMode::Phrase => {
            let mut resp = item_search(index, reader, &schema, q, prefix, limit);
            if !overlay.is_empty() {
                resp.hits
                    .retain(|h| h.source_path.as_ref().is_none_or(|p| !overlay.contains(p)));
            }
            resp
        }
        QueryMode::BufferLocal => empty,
    }
}

fn empty_resp(query_id: u64) -> CompletionResponse {
    CompletionResponse::empty(query_id)
}
