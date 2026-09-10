use tantivy::schema::Value;
use tantivy::{Searcher, TantivyDocument};

use crate::ffi::CompletionHit;
use crate::index::item_kind_from_label;

const HUMP_PENALTY: f32 = 100.0;

pub fn doc_hit(
    searcher: &Searcher,
    schema: &tantivy::schema::Schema,
    addr: tantivy::DocAddress,
    score: f32,
    prefix_lower: &str,
) -> Option<CompletionHit> {
    let doc = searcher.doc::<TantivyDocument>(addr).ok()?;
    let field = |n: &str| schema.get_field(n).ok().and_then(|f| field_str(&doc, f));
    let name = field("name")?;
    let by_name = name.to_ascii_lowercase().starts_with(prefix_lower);
    if !by_name && !crate::index::hump(&name).starts_with(prefix_lower) {
        return None;
    }
    let score = if by_name { score } else { score - HUMP_PENALTY };
    let path = field("path").unwrap_or_else(|| name.clone());
    let crate_name = field("crate").unwrap_or_default();
    let kind = field("item_kind").unwrap_or_default();
    let paragraph = field("doc_first_paragraph").unwrap_or_default();
    Some(CompletionHit {
        path,
        name: name.clone(),
        insert_text: name,
        item_kind: item_kind_from_label(&kind),
        crate_name,
        crate_version: field("version").unwrap_or_default(),
        signature: field("signature").unwrap_or_default(),
        doc_first_sentence: first_sentence(&paragraph),
        doc_paragraph: paragraph.clone(),
        detail: String::new(),
        import_path: None,
        deprecated: false,
        snippet: false,
        replace_start_byte: None,
        source_path: field("source_path"),
        byte_start: field_u32(&doc, schema, "byte_start"),
        byte_end: field_u32(&doc, schema, "byte_end"),
        score,
    })
}

pub fn field_str(doc: &TantivyDocument, field: tantivy::schema::Field) -> Option<String> {
    doc.get_first(field)
        .and_then(|v| v.as_str())
        .map(str::to_string)
}

fn field_u32(doc: &TantivyDocument, schema: &tantivy::schema::Schema, name: &str) -> Option<u32> {
    let f = schema.get_field(name).ok()?;
    doc.get_first(f).and_then(|v| v.as_u64()).map(|n| n as u32)
}

fn first_sentence(doc: &str) -> String {
    let t = doc.trim();
    if t.is_empty() {
        return String::new();
    }
    t.split_once('.')
        .map(|(a, _)| a.trim().to_string())
        .unwrap_or_else(|| t.to_string())
}
