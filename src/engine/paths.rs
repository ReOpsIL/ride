use std::path::Path;

use crate::ffi::{CompletionContext, CompletionHit, CompletionQuery, CompletionResponse, ItemKind};
use crate::query;
use crate::score::KEYWORD;

use super::merge;
use super::snapshot::Snapshot;

const ROOTS: &[&str] = &["crate", "self", "super", "std", "core", "alloc"];
const IN_GROUP: &[&str] = &["self", "*"];

pub fn use_hits(snap: &Snapshot, q: &CompletionQuery, segments: &[String]) -> CompletionResponse {
    if segments.is_empty() {
        return crates(snap, q);
    }
    let mut pool = children(snap, q, segments);
    pool.retain(|h| h.item_kind != ItemKind::Method);
    pool.extend(specials(IN_GROUP, &q.prefix));
    merge::finish(q, pool, false)
}

pub fn scoped_hits(
    snap: &Snapshot,
    q: &CompletionQuery,
    segments: &[String],
) -> CompletionResponse {
    if segments.is_empty() {
        return crates(snap, q);
    }
    let pool = children(snap, q, segments);
    merge::finish(q, pool, false)
}

fn crates(snap: &Snapshot, q: &CompletionQuery) -> CompletionResponse {
    let limit = if q.limit == 0 { 20 } else { q.limit } as usize;
    let mut pool = Vec::new();
    if snap.lang.has_catalog() {
        let mut hits = query::listed(
            snap.catalog.src(),
            query::Filter::Kind(ItemKind::Crate),
            &q.prefix,
            limit,
            q.context,
        );
        merge::boost_catalog(&mut hits, &q.prefix, &[]);
        pool.extend(hits);
    }
    pool.extend(specials(ROOTS, &q.prefix));
    merge::finish(q, pool, false)
}

fn children(snap: &Snapshot, q: &CompletionQuery, segments: &[String]) -> Vec<CompletionHit> {
    if !snap.lang.has_catalog() {
        return Vec::new();
    }
    let limit = if q.limit == 0 { 20 } else { q.limit } as usize;
    let Some(parent) = resolve(snap, segments) else {
        return Vec::new();
    };
    let context = if segments
        .last()
        .and_then(|s| s.chars().next())
        .is_some_and(char::is_uppercase)
    {
        CompletionContext::MemberAccess
    } else {
        q.context
    };
    let mut hits = query::children(snap.catalog.src(), &parent, &q.prefix, limit, context);
    merge::boost_catalog(&mut hits, &q.prefix, &[]);
    for hit in &mut hits {
        hit.import_path = None;
    }
    hits
}

fn resolve(snap: &Snapshot, segments: &[String]) -> Option<String> {
    let mut segs: Vec<String> = segments.to_vec();
    match segs.first().map(String::as_str) {
        Some("crate") => {
            segs[0] = snap.workspace.as_ref()?.package_name.clone()?;
        }
        Some("self") | Some("super") => {
            let mut module = module_path(snap)?;
            if segs[0] == "super" {
                module.pop();
            }
            segs.splice(0..1, module);
        }
        _ => {}
    }
    Some(segs.join("::"))
}

fn module_path(snap: &Snapshot) -> Option<Vec<String>> {
    let workspace = snap.workspace.as_ref()?;
    let package = workspace.package_name.clone()?;
    let file = snap.scope.as_ref()?.path.clone()?;
    let rel = file.strip_prefix(Path::new(&workspace.root)).ok()?;
    let mut parts: Vec<String> = rel
        .components()
        .map(|c| c.as_os_str().to_string_lossy().to_string())
        .collect();
    if parts.first().map(String::as_str) == Some("src") {
        parts.remove(0);
    }
    let last = parts.pop()?;
    let stem = last.strip_suffix(".rs").unwrap_or(&last);
    if !matches!(stem, "lib" | "main" | "mod") {
        parts.push(stem.to_string());
    }
    let mut out = vec![package];
    out.extend(parts);
    Some(out)
}

fn specials(words: &[&str], prefix: &str) -> Vec<CompletionHit> {
    words
        .iter()
        .filter(|w| w.starts_with(prefix))
        .map(|w| CompletionHit::local(w, ItemKind::Keyword, KEYWORD, None))
        .collect()
}
