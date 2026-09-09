use crate::ffi::{CompletionHit, ItemKind};

pub const KEYWORDS: &[&str] = &[
    "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
    "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
    "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type",
    "unsafe", "use", "where", "while",
];

pub fn keyword_hits(prefix: &str, limit: u32) -> Vec<CompletionHit> {
    let p = prefix.to_ascii_lowercase();
    KEYWORDS
        .iter()
        .filter(|k| p.is_empty() || k.to_ascii_lowercase().starts_with(&p))
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
            score: 50.0,
        })
        .collect()
}
