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
                .map(|o| hit(o, DEFINITION_SCORE, Some(h.path.display().to_string())))
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
                out.push(hit(
                    item,
                    COMPLETION_SCORE,
                    Some(header.path.display().to_string()),
                ));
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
    member_hits(TypeTable::resolve(tables, type_name), prefix, limit)
}

pub fn scoped(
    tables: &[&TypeTable],
    segments: &[String],
    prefix: &str,
    limit: usize,
) -> Vec<CompletionHit> {
    member_hits(TypeTable::scoped(tables, segments), prefix, limit)
}

fn member_hits(members: Vec<Member>, prefix: &str, limit: usize) -> Vec<CompletionHit> {
    let p = prefix.to_ascii_lowercase();
    let mut seen = HashSet::new();
    members
        .into_iter()
        .filter(|m| matches(&m.item.name, &p))
        .filter(|m| m.origin.is_none() || !reserved(&m.item.name, prefix))
        .filter(|m| seen.insert(m.item.name.clone()))
        .take(limit)
        .map(|m: Member| {
            hit(
                &m.item,
                MEMBER_SCORE,
                m.origin.map(|o| o.display().to_string()),
            )
        })
        .collect()
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

fn hit(item: &OutlineItem, score: f32, source_path: Option<String>) -> CompletionHit {
    let mut hit = CompletionHit::local(
        &item.name,
        item.kind,
        score,
        Some((item.start_byte, item.end_byte)),
    );
    hit.source_path = source_path;
    hit
}
