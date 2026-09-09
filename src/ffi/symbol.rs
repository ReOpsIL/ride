use super::query::CompletionHit;

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
