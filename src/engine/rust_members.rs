use std::collections::HashSet;

use crate::ffi::{CompletionContext, CompletionHit, CompletionQuery, CompletionResponse, ItemKind};
use crate::highlight::Site;
use crate::query;

use super::snapshot::Snapshot;
use super::{header_hits, merge, struct_literal};

const CATALOG_KINDS: &[ItemKind] = &[
    ItemKind::Method,
    ItemKind::Variant,
    ItemKind::Const,
    ItemKind::Type,
    ItemKind::Fn,
];

pub fn try_hits(snap: &Snapshot, q: &CompletionQuery) -> Option<CompletionResponse> {
    if !snap.lang.has_catalog() {
        return None;
    }
    match &snap.site.as_ref()?.site {
        Site::MemberAccess => members(snap, q),
        Site::StructLiteral(name) => struct_literal::hits(snap, q, name),
        _ => None,
    }
}

pub fn buffer_members(snap: &Snapshot, type_name: &str, prefix: &str) -> Vec<CompletionHit> {
    snap.scope
        .as_ref()
        .map(|scope| header_hits::members(&scope.types, &[], type_name, prefix, usize::MAX))
        .unwrap_or_default()
}

fn members(snap: &Snapshot, q: &CompletionQuery) -> Option<CompletionResponse> {
    let type_name = snap.local.as_ref()?.access.as_ref()?.type_name.as_deref()?;
    let limit = if q.limit == 0 { 20 } else { q.limit } as usize;
    let mut pool = buffer_members(snap, type_name, &q.prefix);
    merge::keep_order(&mut pool, &q.prefix);
    let defined_here = snap
        .scope
        .as_ref()
        .is_some_and(|s| s.types.defines(type_name))
        && !snap.imports.iter().any(|i| i == type_name);
    if defined_here {
        return (!pool.is_empty()).then(|| merge::finish(q, pool, false));
    }
    let taken: HashSet<String> = pool.iter().map(|h| h.name.clone()).collect();
    let catalog = query::children(
        snap.catalog.src(),
        type_name,
        &q.prefix,
        limit,
        CompletionContext::MemberAccess,
    );
    pool.extend(
        catalog
            .into_iter()
            .filter(|h| CATALOG_KINDS.contains(&h.item_kind) && !taken.contains(&h.name)),
    );
    (!pool.is_empty()).then(|| merge::finish(q, pool, false))
}
