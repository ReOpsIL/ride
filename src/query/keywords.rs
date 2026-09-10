use crate::ffi::{CompletionHit, ItemKind};

use super::rank::{EXACT, KEYWORD, length_bonus};

pub fn keyword_hits(keywords: &[&str], prefix: &str, limit: u32) -> Vec<CompletionHit> {
    keywords
        .iter()
        .filter(|k| prefix.is_empty() || k.starts_with(prefix))
        .take(limit as usize)
        .map(|k| CompletionHit::local(k, ItemKind::Keyword, score(k, prefix), None))
        .collect()
}

fn score(keyword: &str, prefix: &str) -> f32 {
    let exact = if keyword == prefix { EXACT } else { 0.0 };
    KEYWORD + exact + length_bonus(keyword.len() as u64)
}
