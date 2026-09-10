use std::collections::HashMap;

use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, ItemKind};
use crate::score::{IMPORT_BONUS, PRELUDE_BONUS, case_bonus, exact_bonus, tiered};

const PRELUDE: &[&str] = &[
    "Vec",
    "String",
    "Option",
    "Some",
    "None",
    "Result",
    "Ok",
    "Err",
    "Box",
    "Copy",
    "Clone",
    "Send",
    "Sync",
    "Sized",
    "Drop",
    "Fn",
    "FnMut",
    "FnOnce",
    "Iterator",
    "IntoIterator",
    "Extend",
    "Default",
    "Eq",
    "PartialEq",
    "Ord",
    "PartialOrd",
    "AsRef",
    "AsMut",
    "Into",
    "From",
    "ToOwned",
    "ToString",
    "TryFrom",
    "TryInto",
    "drop",
    "Debug",
    "Hash",
];

const NOT_IMPORTABLE: &[ItemKind] = &[
    ItemKind::Method,
    ItemKind::Field,
    ItemKind::Variant,
    ItemKind::Keyword,
    ItemKind::Local,
    ItemKind::Crate,
    ItemKind::Header,
];

pub fn keep_order(hits: &mut [CompletionHit], prefix: &str) {
    for (position, hit) in hits.iter_mut().enumerate() {
        hit.score = hit.score + exact_bonus(&hit.name, prefix) + case_bonus(&hit.name, prefix)
            - position as f32 * 0.5;
    }
}

pub fn tier_all(hits: &mut [CompletionHit], prefix: &str) {
    for hit in hits {
        hit.score = tiered(hit.score, &hit.name, hit.item_kind, prefix);
    }
}

pub fn boost_catalog(hits: &mut [CompletionHit], prefix: &str, imports: &[String]) {
    for hit in hits {
        let imported = imports.contains(&hit.name);
        hit.score += case_bonus(&hit.name, prefix);
        if imported {
            hit.score += IMPORT_BONUS;
        } else if PRELUDE.contains(&hit.name.as_str()) {
            hit.score += PRELUDE_BONUS;
        } else if !NOT_IMPORTABLE.contains(&hit.item_kind) && hit.path.contains("::") {
            hit.import_path = Some(hit.path.clone());
        }
    }
}

pub fn finish(
    q: &CompletionQuery,
    hits: Vec<CompletionHit>,
    truncated: bool,
) -> CompletionResponse {
    let limit = if q.limit == 0 { 20 } else { q.limit } as usize;
    let mut groups: HashMap<String, CompletionHit> = HashMap::new();
    for hit in hits {
        match groups.get_mut(&hit.name) {
            None => {
                groups.insert(hit.name.clone(), hit);
            }
            Some(prev) => {
                let best = prev.score.max(hit.score);
                if prefer(&hit, prev) {
                    *prev = hit;
                }
                prev.score = best;
            }
        }
    }
    let mut out: Vec<CompletionHit> = groups.into_values().collect();
    out.sort_by(|a, b| b.score.total_cmp(&a.score).then(a.name.cmp(&b.name)));
    let truncated = truncated || out.len() > limit;
    out.truncate(limit);
    CompletionResponse::new(q.query_id, out, truncated)
}

fn prefer(candidate: &CompletionHit, current: &CompletionHit) -> bool {
    let weak = |h: &CompletionHit| matches!(h.item_kind, ItemKind::Local | ItemKind::Keyword);
    match (weak(current), weak(candidate)) {
        (true, false) => true,
        (false, true) => false,
        _ => candidate.score > current.score,
    }
}
