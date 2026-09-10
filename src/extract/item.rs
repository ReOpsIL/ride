use std::path::PathBuf;

use crate::ffi::ItemKind;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Visibility {
    Pub,
    Crate,
    Private,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scope {
    Workspace,
    Sysroot,
    DirectDep,
    Transitive,
    Cache,
}

#[derive(Debug, Clone)]
pub struct CrateContext {
    pub crate_name: String,
    pub crate_version: String,
    pub crate_root: PathBuf,
    pub edition: Option<String>,
    pub features: Vec<String>,
    pub scope: Scope,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ItemDoc {
    pub crate_name: String,
    pub crate_version: String,
    pub item_kind: ItemKind,
    pub path: String,
    pub name: String,
    pub signature: String,
    pub doc_first_paragraph: String,
    pub source_chunk: String,
    pub source_path: PathBuf,
    pub byte_range: (u32, u32),
    pub edition: Option<String>,
    pub features: Vec<String>,
    pub visibility: Visibility,
    pub scope: Scope,
    pub reachable: bool,
    pub deprecated: bool,
}

pub struct ItemParts {
    pub kind: ItemKind,
    pub path: String,
    pub name: String,
    pub vis: Visibility,
    pub source_path: PathBuf,
    pub byte_range: (u32, u32),
    pub signature: String,
    pub doc: String,
    pub chunk: String,
    pub reachable: bool,
    pub deprecated: bool,
}

impl ItemDoc {
    pub fn from_ctx(ctx: &CrateContext, parts: ItemParts) -> Self {
        Self {
            crate_name: ctx.crate_name.clone(),
            crate_version: ctx.crate_version.clone(),
            item_kind: parts.kind,
            path: parts.path,
            name: parts.name,
            signature: parts.signature,
            doc_first_paragraph: parts.doc,
            source_chunk: parts.chunk,
            source_path: parts.source_path,
            byte_range: parts.byte_range,
            edition: ctx.edition.clone(),
            features: ctx.features.clone(),
            visibility: parts.vis,
            scope: ctx.scope,
            reachable: parts.reachable,
            deprecated: parts.deprecated,
        }
    }
}

pub fn join_path(module: &[String], name: &str) -> String {
    if module.is_empty() {
        name.to_string()
    } else {
        format!("{}::{name}", module.join("::"))
    }
}

pub fn byte_range(node: tree_sitter::Node<'_>) -> (u32, u32) {
    (node.start_byte() as u32, node.end_byte() as u32)
}

pub fn field_text(node: tree_sitter::Node<'_>, field: &str, source: &str) -> Option<String> {
    node.child_by_field_name(field)
        .and_then(|n| n.utf8_text(source.as_bytes()).ok())
        .map(str::to_string)
}

pub fn node_text(node: tree_sitter::Node<'_>, source: &str) -> String {
    node.utf8_text(source.as_bytes())
        .unwrap_or("")
        .trim()
        .to_string()
}
