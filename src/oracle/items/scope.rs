use crate::ffi::CompletionHit;

use super::parse::Parsed;

pub fn scope(mut items: Vec<Parsed>) -> Vec<CompletionHit> {
    items.sort_by(|a, b| {
        a.sort_text
            .cmp(&b.sort_text)
            .then_with(|| a.hit.name.cmp(&b.hit.name))
    });
    let mut seen = std::collections::HashSet::new();
    items
        .into_iter()
        .map(|p| p.hit)
        .filter(|hit| seen.insert(hit.name.clone()))
        .collect()
}
