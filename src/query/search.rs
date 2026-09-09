use std::collections::HashSet;
use std::path::Path;

use tantivy::{Index, IndexReader};

use crate::ffi::{CompletionQuery, CompletionResponse, ItemKind, QueryMode};
use crate::index::live_index_dir;

use super::items::item_search;

pub fn search_index(
    index_dir: &Path,
    q: &CompletionQuery,
    overlay: &HashSet<String>,
) -> CompletionResponse {
    let empty = empty_resp(q.query_id);
    let Some(live) = live_index_dir(index_dir) else {
        return empty;
    };
    let Ok(index) = Index::open_in_dir(live) else {
        return empty;
    };
    let Ok(reader) = index.reader() else {
        return empty;
    };
    search_open(&index, &reader, q, overlay)
}

pub fn search_open(
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
    let limit = if q.limit == 0 { 20 } else { q.limit };
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
    CompletionResponse {
        query_id,
        hits: Vec::new(),
        truncated: false,
    }
}
