use crate::ffi::{CompletionHit, ItemKind};

use super::rank::{EXACT, KEYWORD, length_bonus};

pub const KEYWORDS: &[&str] = &[
    "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
    "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
    "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type",
    "unsafe", "use", "where", "while",
];

pub fn keyword_hits(prefix: &str, limit: u32) -> Vec<CompletionHit> {
    KEYWORDS
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
