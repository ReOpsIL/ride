use crate::ffi::{ItemKind, OutlineItem};
use crate::highlight::Lang;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefKind {
    Call,
    TypeMention,
    FieldAccess,
    UsePath,
    Include,
    Ident,
}

impl RefKind {
    pub fn label(self) -> &'static str {
        match self {
            RefKind::Call => "call",
            RefKind::TypeMention => "type",
            RefKind::FieldAccess => "field",
            RefKind::UsePath => "use",
            RefKind::Include => "include",
            RefKind::Ident => "ident",
        }
    }

    pub fn from_label(label: &str) -> RefKind {
        match label {
            "call" => RefKind::Call,
            "type" => RefKind::TypeMention,
            "field" => RefKind::FieldAccess,
            "use" => RefKind::UsePath,
            "include" => RefKind::Include,
            _ => RefKind::Ident,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RefRecord {
    pub name: String,
    pub kind: RefKind,
    pub path: String,
    pub line: u32,
    pub byte_start: u32,
    pub byte_end: u32,
    pub enclosing_item: String,
    pub enclosing_kind: ItemKind,
}

pub trait RefExtractor {
    fn extract(&self, lang: Lang, text: &str) -> Vec<RefRecord>;
}

pub struct StubExtractor;

impl RefExtractor for StubExtractor {
    fn extract(&self, _lang: Lang, _text: &str) -> Vec<RefRecord> {
        Vec::new()
    }
}

pub fn extractor_for(lang: Lang) -> Box<dyn RefExtractor> {
    match lang {
        Lang::Rust => Box::new(super::rust::RustExtractor),
        Lang::C | Lang::Cpp => Box::new(super::c::CExtractor),
        _ => Box::new(StubExtractor),
    }
}

pub(super) fn enclosing(outline: &[OutlineItem], byte: u32) -> (String, ItemKind) {
    outline
        .iter()
        .filter(|o| o.start_byte <= byte && byte < o.end_byte)
        .min_by_key(|o| o.end_byte - o.start_byte)
        .map(|o| (o.name.clone(), o.kind))
        .unwrap_or_else(|| (String::new(), ItemKind::Mod))
}
