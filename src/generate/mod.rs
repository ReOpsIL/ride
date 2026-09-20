mod cpp;
mod rust;
mod types;

pub use types::{Field, GenType};

use crate::ffi::{GenKind, GenOption, ItemKind, OutlineItem};
use crate::highlight::Lang;

const CPP_KINDS: [GenKind; 5] = [
    GenKind::Constructor,
    GenKind::Getters,
    GenKind::Setters,
    GenKind::EqualityOps,
    GenKind::StreamInsert,
];

pub fn enclosing_type(outline: &[OutlineItem], cursor: u32) -> Option<&OutlineItem> {
    outline
        .iter()
        .filter(|i| matches!(i.kind, ItemKind::Class | ItemKind::Struct | ItemKind::Union))
        .filter(|i| i.start_byte <= cursor && cursor <= i.end_byte)
        .min_by_key(|i| i.end_byte - i.start_byte)
}

pub fn options(t: &GenType, lang: Lang, buffer: &str) -> Vec<GenOption> {
    if t.fields.is_empty() {
        return Vec::new();
    }
    match lang {
        Lang::Rust => rust::options(t, buffer),
        _ => CPP_KINDS
            .iter()
            .map(|&kind| GenOption {
                kind,
                title: title(kind),
            })
            .collect(),
    }
}

pub fn apply(t: &GenType, kind: GenKind) -> String {
    match kind {
        GenKind::Constructor => cpp::constructor(t),
        GenKind::Getters => cpp::getters(t),
        GenKind::Setters => cpp::setters(t),
        GenKind::EqualityOps => cpp::equality(t),
        GenKind::StreamInsert => cpp::stream_insert(t),
        GenKind::ImplBlock | GenKind::DefaultImpl | GenKind::DisplayImpl | GenKind::New => {
            rust::apply(t, kind)
        }
    }
}

fn title(kind: GenKind) -> String {
    match kind {
        GenKind::Constructor => "Constructor".to_string(),
        GenKind::Getters => "Getters".to_string(),
        GenKind::Setters => "Setters".to_string(),
        GenKind::EqualityOps => "Equality operators".to_string(),
        GenKind::StreamInsert => "Stream operator".to_string(),
        GenKind::ImplBlock | GenKind::DefaultImpl | GenKind::DisplayImpl | GenKind::New => {
            rust::title(kind)
        }
    }
}

#[cfg(test)]
mod tests;
