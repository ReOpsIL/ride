use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, ItemKind, QueryMode};
use crate::query;
use crate::score::{KEYWORD, tiered};

use super::merge;
use super::snapshot::Snapshot;

const DIRECTIVES: &[&str] = &[
    "include",
    "define",
    "undef",
    "if",
    "ifdef",
    "ifndef",
    "elif",
    "elifdef",
    "elifndef",
    "else",
    "endif",
    "pragma",
    "error",
    "warning",
    "line",
    "import",
    "embed",
    "pragma once",
];

const ATTRIBUTES: &[&str] = &[
    "allow",
    "warn",
    "deny",
    "forbid",
    "expect",
    "cfg",
    "cfg_attr",
    "derive",
    "doc",
    "inline",
    "must_use",
    "deprecated",
    "test",
    "ignore",
    "should_panic",
    "bench",
    "macro_use",
    "macro_export",
    "path",
    "repr",
    "non_exhaustive",
    "no_mangle",
    "link",
    "link_name",
    "cold",
    "track_caller",
    "automatically_derived",
    "global_allocator",
    "panic_handler",
    "target_feature",
    "proc_macro",
    "proc_macro_derive",
    "proc_macro_attribute",
    "no_std",
    "no_main",
    "feature",
    "recursion_limit",
    "diagnostic::on_unimplemented",
];

const DERIVES: &[&str] = &[
    "Clone",
    "Copy",
    "Debug",
    "Default",
    "Eq",
    "PartialEq",
    "Ord",
    "PartialOrd",
    "Hash",
];

pub fn directives(q: &CompletionQuery) -> CompletionResponse {
    merge::finish(q, words(DIRECTIVES, &q.prefix, ItemKind::Keyword), false)
}

pub fn attributes(snap: &Snapshot, q: &CompletionQuery, derive: bool) -> CompletionResponse {
    let mut pool = if derive {
        words(DERIVES, &q.prefix, ItemKind::Trait)
    } else {
        words(ATTRIBUTES, &q.prefix, ItemKind::Keyword)
    };
    if derive && snap.lang.has_catalog() && q.prefix.chars().count() >= 2 {
        let mut cq = q.clone();
        cq.mode = QueryMode::Items;
        cq.kind_filter = Some(ItemKind::Macro);
        pool.extend(query::search(snap.catalog.src(), &cq, &snap.catalog.overlay).hits);
    }
    merge::finish(q, pool, false)
}

fn words(list: &[&str], prefix: &str, kind: ItemKind) -> Vec<CompletionHit> {
    let low = prefix.to_ascii_lowercase();
    list.iter()
        .filter(|w| w.to_ascii_lowercase().starts_with(&low))
        .map(|w| CompletionHit::local(w, kind, tiered(KEYWORD, w, kind, prefix), None))
        .collect()
}
