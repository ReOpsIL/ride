use super::query::CompletionHit;
use super::session::HighlightSpan;

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct SymbolAt {
    pub name: String,
    pub start_byte: u32,
    pub end_byte: u32,
    pub qualifier: Option<String>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct DefinitionResponse {
    pub symbol: Option<SymbolAt>,
    pub hits: Vec<CompletionHit>,
}

impl DefinitionResponse {
    pub fn empty() -> Self {
        Self {
            symbol: None,
            hits: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct DefinitionExcerpt {
    pub path: String,
    pub line: u32,
    pub text: String,
    pub truncated: bool,
    pub label: String,
    pub highlights: Vec<HighlightSpan>,
    pub byte_start: u32,
}
