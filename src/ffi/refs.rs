use super::kind::ItemKind;

#[derive(Debug, Clone, uniffi::Record)]
pub struct UsageHit {
    pub path: String,
    pub line: u32,
    pub byte_start: u32,
    pub byte_end: u32,
    pub enclosing_item: String,
    pub enclosing_kind: ItemKind,
    pub ref_kind: String,
    pub in_definition_scope: bool,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct UsagesResponse {
    pub name: String,
    pub has_definition: bool,
    pub hits: Vec<UsageHit>,
}

impl UsagesResponse {
    pub fn empty() -> Self {
        Self {
            name: String::new(),
            has_definition: false,
            hits: Vec::new(),
        }
    }
}
