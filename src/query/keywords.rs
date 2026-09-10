use crate::ffi::{CompletionHit, ItemKind};

use super::rank::{EXACT, KEYWORD, length_bonus};

pub fn keyword_hits(keywords: &[&str], prefix: &str, limit: u32) -> Vec<CompletionHit> {
    keywords
        .iter()
        .filter(|k| prefix.is_empty() || k.starts_with(prefix))
        .take(limit as usize)
        .map(|k| CompletionHit {
            path: (*k).to_string(),
            name: (*k).to_string(),
            insert_text: (*k).to_string(),
            item_kind: ItemKind::Keyword,
            crate_name: String::new(),
            crate_version: String::new(),
            signature: String::new(),
            doc_first_sentence: String::new(),
            doc_paragraph: String::new(),
            source_path: None,
            byte_start: None,
            byte_end: None,
            score: score(k, prefix),
        })
        .collect()
}

fn score(keyword: &str, prefix: &str) -> f32 {
    let exact = if keyword == prefix { EXACT } else { 0.0 };
    KEYWORD + exact + length_bonus(keyword.len() as u64)
}
