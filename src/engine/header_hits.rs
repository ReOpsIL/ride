use std::collections::HashSet;
use std::path::Path;
use std::sync::Arc;

use crate::ffi::CompletionHit;
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
            if matches(&item.name, &p) && seen.insert(item.name.clone()) {
                out.push(item_hit(header, item, COMPLETION_SCORE));
            }
        }
    }
    out
}

pub fn members(
    local: &TypeTable,
    headers: &[Arc<Header>],
    type_name: &str,
    prefix: &str,
    limit: usize,
) -> Vec<CompletionHit> {
    let mut tables: Vec<&TypeTable> = vec![local];
    tables.extend(headers.iter().map(|h| &h.summary.types));
    let p = prefix.to_ascii_lowercase();
    let mut seen = HashSet::new();
    TypeTable::resolve(&tables, type_name)
        .into_iter()
        .filter(|m| matches(&m.item.name, &p) && seen.insert(m.item.name.clone()))
        .take(limit)
        .map(|m: Member| {
            let origin = m.origin.map(|o| o.display().to_string());
            let mut hit = CompletionHit::from_outline(&m.item, MEMBER_SCORE, origin);
            hit.detail = m.detail;
            hit
        })
        .collect()
}

fn matches(name: &str, prefix_lower: &str) -> bool {
    prefix_lower.is_empty() || name.to_ascii_lowercase().starts_with(prefix_lower)
}

fn item_hit(header: &Header, item: &crate::ffi::OutlineItem, score: f32) -> CompletionHit {
    let mut hit = CompletionHit::from_outline(item, score, Some(header.path.display().to_string()));
    hit.detail = file_name(&header.path);
    hit
}

fn file_name(path: &Path) -> String {
    path.file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default()
}
