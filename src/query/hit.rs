use tantivy::schema::Value;
use tantivy::{Searcher, TantivyDocument};

use crate::ffi::{CompletionHit, ItemKind};
use crate::index::item_kind_from_label;

pub fn doc_hit(
    searcher: &Searcher,
    schema: &tantivy::schema::Schema,
    addr: tantivy::DocAddress,
    score: f32,
    prefix: &str,
) -> Option<CompletionHit> {
    let doc = searcher.doc::<TantivyDocument>(addr).ok()?;
    let field = |n: &str| schema.get_field(n).ok().and_then(|f| field_str(&doc, f));
    let name = field("name")?;
    let path = field("path").unwrap_or_else(|| name.clone());
    let crate_name = field("crate").unwrap_or_default();
    let scope = field("scope").unwrap_or_default();
    let kind = field("item_kind").unwrap_or_default();
    let mut s = score * scope_boost(&scope);
    let low = prefix.to_ascii_lowercase();
    if name.eq_ignore_ascii_case(prefix) {
        s += 25.0;
    } else if name.to_ascii_lowercase().starts_with(&low) {
        s += 10.0;
    }
    Some(CompletionHit {
        path,
        name: name.clone(),
        insert_text: name,
        item_kind: item_kind_from_label(&kind),
        crate_name,
        crate_version: field("version").unwrap_or_default(),
        signature: field("signature").unwrap_or_default(),
        doc_first_sentence: first_sentence(&field("doc_first_paragraph").unwrap_or_default()),
        source_path: field("source_path"),
        byte_start: field_u32(&doc, schema, "byte_start"),
        byte_end: field_u32(&doc, schema, "byte_end"),
        score: s,
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

fn scope_boost(scope: &str) -> f32 {
    match scope {
        "workspace" => 8.0,
        "sysroot" | "direct_dep" => 6.0,
        "transitive" => 3.0,
        _ => 1.0,
    }
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

pub fn crate_hit(name: String, score: f32) -> CompletionHit {
    CompletionHit {
        path: name.clone(),
        name: name.clone(),
        insert_text: name.clone(),
        item_kind: ItemKind::Crate,
        crate_name: name,
        crate_version: String::new(),
        signature: String::new(),
        doc_first_sentence: String::new(),
        source_path: None,
        byte_start: None,
        byte_end: None,
        score,
    }
}
