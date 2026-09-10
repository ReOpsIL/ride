use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, ItemKind};
use crate::highlight::SiteAt;
use crate::score::{KEYWORD, tiered};

use super::merge;
use super::snapshot::Snapshot;
use super::snippets::render;

const TEMPLATES: &[(&str, &[&str])] = &[
    ("if", &["if {recv} {", "    $0", "}"]),
    ("match", &["match {recv} {", "    $0", "}"]),
    ("while", &["while {recv} {", "    $0", "}"]),
    ("let", &["let ${1:name} = {recv};$0"]),
    ("not", &["!{recv}$0"]),
    ("ref", &["&{recv}$0"]),
    ("refm", &["&mut {recv}$0"]),
    ("dbg", &["dbg!({recv})$0"]),
    ("return", &["return {recv};$0"]),
    ("some", &["Some({recv})$0"]),
    ("ok", &["Ok({recv})$0"]),
    ("err", &["Err({recv})$0"]),
    ("box", &["Box::new({recv})$0"]),
    ("println", &["println!(\"{{:?}}\", {recv});$0"]),
];

pub fn append(resp: &mut CompletionResponse, snap: &Snapshot, q: &CompletionQuery, site: &SiteAt) {
    let Some((start, end)) = snap.postfix_receiver else {
        return;
    };
    if q.prefix.is_empty() || end <= start {
        return;
    }
    let Some(receiver) = snap.receiver_text.as_deref() else {
        return;
    };
    let extra: Vec<CompletionHit> = TEMPLATES
        .iter()
        .filter(|(k, _)| k.starts_with(q.prefix.as_str()))
        .map(|(k, lines)| {
            let body = render(lines, &site.line_indent).replace("{recv}", receiver);
            let mut hit = CompletionHit::local(k, ItemKind::Keyword, 0.0, None);
            hit.score = tiered(KEYWORD, k, ItemKind::Keyword, &q.prefix);
            hit.insert_text = body;
            hit.snippet = true;
            hit.detail = "postfix".into();
            hit.replace_start_byte = Some(start as u32);
            hit
        })
        .collect();
    if extra.is_empty() {
        return;
    }
    let mut pool = std::mem::take(&mut resp.hits);
    pool.extend(extra);
    let merged = merge::finish(q, pool, resp.truncated);
    resp.hits = merged.hits;
    resp.truncated = merged.truncated;
}
