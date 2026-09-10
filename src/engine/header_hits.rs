use std::collections::HashSet;
use std::sync::Arc;

use crate::ffi::{CompletionHit, OutlineItem};
use crate::highlight::{Member, TypeTable};

use super::headers::Header;

const DEFINITION_SCORE: f32 = 1999.0;
const MEMBER_SCORE: f32 = crate::score::TIER_ITEM;
const COMPLETION_SCORE: f32 = crate::score::TIER_HEADER;

pub fn definitions(headers: &[Arc<Header>], name: &str) -> Vec<CompletionHit> {
    headers
        .iter()
        .flat_map(|h| {
            h.summary
                .outline
                .iter()
                .filter(|o| o.name == name)
                .map(|o| item_hit(h, o, DEFINITION_SCORE))
        })
        .collect()
}

pub fn completions(headers: &[Arc<Header>], prefix: &str, limit: usize) -> Vec<CompletionHit> {
    let p = prefix.to_ascii_lowercase();
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for header in headers {
        for item in &header.summary.outline {
            if out.len() >= limit {
                return out;
            }
            if matches(&item.name, &p)
                && !reserved(&item.name, prefix)
                && seen.insert(item.name.clone())
            {
                out.push(item_hit(header, item, COMPLETION_SCORE));
            }
        }
    }
    out
}

pub fn tables<'a>(local: &'a TypeTable, headers: &'a [Arc<Header>]) -> Vec<&'a TypeTable> {
    let mut tables: Vec<&TypeTable> = vec![local];
    tables.extend(headers.iter().map(|h| &h.summary.types));
    tables
}

pub fn members(
    tables: &[&TypeTable],
    type_name: &str,
    prefix: &str,
    limit: usize,
) -> Vec<CompletionHit> {
    member_hits(
        TypeTable::resolve(tables, type_name),
        prefix,
        limit,
        Some(type_name),
    )
}

pub fn scoped(
    tables: &[&TypeTable],
    segments: &[String],
    prefix: &str,
    limit: usize,
) -> Vec<CompletionHit> {
    member_hits(TypeTable::scoped(tables, segments), prefix, limit, None)
}

fn member_hits(
    members: Vec<Member>,
    prefix: &str,
    limit: usize,
    owner: Option<&str>,
) -> Vec<CompletionHit> {
    let p = prefix.to_ascii_lowercase();
    let mut seen = HashSet::new();
    let mut hits: Vec<CompletionHit> = members
        .into_iter()
        .filter(|m| matches(&m.item.name, &p))
        .filter(|m| m.origin.is_none() || !reserved(&m.item.name, prefix))
        .filter(|m| seen.insert(m.item.name.clone()))
        .map(|m: Member| {
            let mut hit = CompletionHit::from_outline(
                &m.item,
                MEMBER_SCORE,
                m.origin.map(|o| o.display().to_string()),
            );
            hit.detail = m.detail;
            hit
        })
        .collect();
    hits.sort_by_key(|h| special(&h.name, owner));
    hits.truncate(limit);
    hits
}

fn special(name: &str, owner: Option<&str>) -> bool {
    name.starts_with('~') || name.starts_with("operator") || owner == Some(name)
}

fn matches(name: &str, prefix_lower: &str) -> bool {
    prefix_lower.is_empty() || name.to_ascii_lowercase().starts_with(prefix_lower)
}

fn reserved(name: &str, prefix: &str) -> bool {
    if prefix.starts_with('_') {
        return false;
    }
    let mut chars = name.chars();
    chars.next() == Some('_')
        && chars
            .next()
            .is_some_and(|c| c == '_' || c.is_ascii_uppercase())
}

fn item_hit(header: &Header, item: &OutlineItem, score: f32) -> CompletionHit {
    let mut hit = CompletionHit::from_outline(item, score, Some(header.path.display().to_string()));
    hit.detail = header
        .path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    hit
}
