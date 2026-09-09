use tantivy::doc;
use tantivy::schema::TantivyDocument;

use crate::extract::{ItemDoc, Scope, Visibility};

use super::schema::{
    IndexFields, item_kind_label, kind_rank, name_hash, scope_label, scope_rank, visibility_label,
};

pub fn keep_item(item: &ItemDoc) -> bool {
    match item.scope {
        Scope::Workspace => true,
        _ => item.visibility == Visibility::Pub,
    }
}

pub fn to_document(fields: &IndexFields, item: &ItemDoc, hash: &str) -> TantivyDocument {
    let path_exact = item.path.to_ascii_lowercase();
    let name_exact = item.name.to_ascii_lowercase();
    let features = item.features.join(",");
    let edition = item.edition.clone().unwrap_or_default();
    let source_path = item.source_path.to_string_lossy().into_owned();
    doc!(
        fields.crate_name => item.crate_name.as_str(),
        fields.version => item.crate_version.as_str(),
        fields.item_kind => item_kind_label(item.item_kind),
        fields.path => item.path.as_str(),
        fields.path_exact => path_exact.as_str(),
        fields.name => item.name.as_str(),
        fields.name_exact => name_exact.as_str(),
        fields.signature => item.signature.as_str(),
        fields.doc => item.doc_first_paragraph.as_str(),
        fields.features => features.as_str(),
        fields.edition => edition.as_str(),
        fields.visibility => visibility_label(item.visibility),
        fields.source_path => source_path.as_str(),
        fields.byte_start => u64::from(item.byte_range.0),
        fields.byte_end => u64::from(item.byte_range.1),
        fields.content_hash => hash,
        fields.scope => scope_label(item.scope),
        fields.name_prefix => item.name.as_str(),
        fields.scope_rank => scope_rank(item.scope),
        fields.kind_rank => kind_rank(item.item_kind),
        fields.name_len => item.name.chars().count() as u64,
        fields.name_hash => name_hash(&item.name),
        fields.path_len => item.path.chars().count() as u64,
        fields.has_doc => u64::from(!item.doc_first_paragraph.trim().is_empty()),
    )
}
