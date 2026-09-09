use tantivy::schema::{Field, NumericOptions, STORED, STRING, Schema, TEXT};

use crate::extract::{Scope, Visibility};
use crate::ffi::ItemKind;

pub const SCHEMA_VERSION: u32 = 1;

pub struct IndexFields {
    pub schema: Schema,
    pub crate_name: Field,
    pub version: Field,
    pub item_kind: Field,
    pub path: Field,
    pub path_exact: Field,
    pub name: Field,
    pub name_exact: Field,
    pub signature: Field,
    pub doc: Field,
    pub source_chunk: Field,
    pub features: Field,
    pub edition: Field,
    pub visibility: Field,
    pub source_path: Field,
    pub byte_start: Field,
    pub byte_end: Field,
    pub content_hash: Field,
    pub scope: Field,
}

pub fn build_fields() -> IndexFields {
    let mut b = Schema::builder();
    let u64_stored = NumericOptions::default().set_stored();
    IndexFields {
        crate_name: b.add_text_field("crate", STRING | STORED),
        version: b.add_text_field("version", STRING | STORED),
        item_kind: b.add_text_field("item_kind", STRING | STORED),
        path: b.add_text_field("path", TEXT | STORED),
        path_exact: b.add_text_field("path_exact", STRING | STORED),
        name: b.add_text_field("name", TEXT | STORED),
        name_exact: b.add_text_field("name_exact", STRING | STORED),
        signature: b.add_text_field("signature", TEXT | STORED),
        doc: b.add_text_field("doc_first_paragraph", TEXT | STORED),
        source_chunk: b.add_text_field("source_chunk", TEXT | STORED),
        features: b.add_text_field("features", STRING | STORED),
        edition: b.add_text_field("edition", STRING | STORED),
        visibility: b.add_text_field("visibility", STRING | STORED),
        source_path: b.add_text_field("source_path", STRING | STORED),
        byte_start: b.add_u64_field("byte_start", u64_stored.clone()),
        byte_end: b.add_u64_field("byte_end", u64_stored),
        content_hash: b.add_text_field("content_hash", STRING | STORED),
        scope: b.add_text_field("scope", STRING | STORED),
        schema: b.build(),
    }
}

pub fn item_kind_from_label(label: &str) -> ItemKind {
    match label {
        "keyword" => ItemKind::Keyword,
        "local" => ItemKind::Local,
        "crate" => ItemKind::Crate,
        "mod" => ItemKind::Mod,
        "struct" => ItemKind::Struct,
        "enum" => ItemKind::Enum,
        "union" => ItemKind::Union,
        "trait" => ItemKind::Trait,
        "fn" => ItemKind::Fn,
        "method" => ItemKind::Method,
        "macro" => ItemKind::Macro,
        "const" => ItemKind::Const,
        "static" => ItemKind::Static,
        _ => ItemKind::Type,
    }
}

pub fn item_kind_label(kind: ItemKind) -> &'static str {
    match kind {
        ItemKind::Keyword => "keyword",
        ItemKind::Local => "local",
        ItemKind::Crate => "crate",
        ItemKind::Mod => "mod",
        ItemKind::Struct => "struct",
        ItemKind::Enum => "enum",
        ItemKind::Union => "union",
        ItemKind::Trait => "trait",
        ItemKind::Fn => "fn",
        ItemKind::Method => "method",
        ItemKind::Macro => "macro",
        ItemKind::Const => "const",
        ItemKind::Type => "type",
        ItemKind::Static => "static",
    }
}

pub fn visibility_label(vis: Visibility) -> &'static str {
    match vis {
        Visibility::Pub => "pub",
        Visibility::Crate => "crate",
        Visibility::Private => "private",
    }
}

pub fn scope_label(scope: Scope) -> &'static str {
    match scope {
        Scope::Workspace => "workspace",
        Scope::Sysroot => "sysroot",
        Scope::DirectDep => "direct_dep",
        Scope::Transitive => "transitive",
        Scope::Cache => "cache",
    }
}
