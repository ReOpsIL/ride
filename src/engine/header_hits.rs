use std::collections::HashSet;
use std::sync::Arc;

use crate::ffi::{CompletionHit, OutlineItem};
use crate::highlight::{Member, TypeTable};

use super::headers::Header;

const DEFINITION_SCORE: f32 = 1999.0;
const MEMBER_SCORE: f32 = 50.0;
const COMPLETION_SCORE: f32 = 42.0;

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
            if matches(&item.name, &p) && seen.insert(item.name.clone()) {
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
