use super::kind::ItemKind;
use super::session::OutlineItem;

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

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum CompletionSiteKind {
    None,
    Identifier,
    MemberAccess,
    ScopedPath,
    UsePath,
    Include,
    Attribute,
    Directive,
    StructLiteral,
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
    pub detail: String,
    pub import_path: Option<String>,
    pub deprecated: bool,
    pub snippet: bool,
    pub replace_start_byte: Option<u32>,
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
    pub replace_start_byte: u32,
    pub site: CompletionSiteKind,
}

impl CompletionHit {
    pub fn local(name: &str, kind: ItemKind, score: f32, range: Option<(u32, u32)>) -> Self {
        Self {
            path: name.to_string(),
            name: name.to_string(),
            insert_text: name.to_string(),
            item_kind: kind,
            crate_name: String::new(),
            crate_version: String::new(),
            signature: String::new(),
            doc_first_sentence: String::new(),
            doc_paragraph: String::new(),
            detail: String::new(),
            import_path: None,
            deprecated: false,
            snippet: false,
            replace_start_byte: None,
            source_path: None,
            byte_start: range.map(|r| r.0),
            byte_end: range.map(|r| r.1),
            score,
        }
    }
}

impl CompletionHit {
    pub fn from_outline(item: &OutlineItem, score: f32, source_path: Option<String>) -> Self {
        let mut hit = Self::local(
            &item.name,
            item.kind,
            score,
            Some((item.start_byte, item.end_byte)),
        );
        hit.signature = item.signature.clone();
        hit.doc_paragraph = item.doc.clone();
        hit.doc_first_sentence = first_sentence(&item.doc);
        hit.source_path = source_path;
        hit
    }
}

pub fn first_sentence(doc: &str) -> String {
    let t = doc.trim();
    if t.is_empty() {
        return String::new();
    }
    t.split_once(". ")
        .map(|(a, _)| a.trim().to_string())
        .or_else(|| t.strip_suffix('.').map(str::to_string))
        .unwrap_or_else(|| t.to_string())
}

impl CompletionResponse {
    pub fn empty(query_id: u64) -> Self {
        Self::new(query_id, Vec::new(), false)
    }

    pub fn new(query_id: u64, hits: Vec<CompletionHit>, truncated: bool) -> Self {
        Self {
            query_id,
            hits,
            truncated,
            replace_start_byte: 0,
            site: CompletionSiteKind::Identifier,
        }
    }

    pub fn at(mut self, replace_start_byte: u32, site: CompletionSiteKind) -> Self {
        self.replace_start_byte = replace_start_byte;
        self.site = site;
        self
    }
}
