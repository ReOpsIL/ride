use super::kind::ItemKind;

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum QueryMode {
    BufferLocal,
    PrefixCrates,
    Items,
    Phrase,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum CompletionContext {
    Unknown,
    TypePosition,
    ValuePosition,
    MemberAccess,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CompletionQuery {
    pub query_id: u64,
    pub session_id: u64,
    pub prefix: String,
    pub mode: QueryMode,
    pub context: CompletionContext,
    pub cursor_byte: u32,
    pub replace_start_byte: u32,
    pub current_crate: Option<String>,
    pub current_module: Option<String>,
    pub kind_filter: Option<ItemKind>,
    pub limit: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CompletionHit {
    pub path: String,
    pub name: String,
    pub insert_text: String,
    pub item_kind: ItemKind,
    pub crate_name: String,
    pub crate_version: String,
    pub signature: String,
    pub doc_first_sentence: String,
    pub doc_paragraph: String,
    pub source_path: Option<String>,
    pub byte_start: Option<u32>,
    pub byte_end: Option<u32>,
    pub score: f32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CompletionResponse {
    pub query_id: u64,
    pub hits: Vec<CompletionHit>,
    pub truncated: bool,
}
