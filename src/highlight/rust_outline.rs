use std::path::Path;

use tree_sitter::Tree;

use crate::extract::{CrateContext, ItemDoc, Scope, extract_parsed, extract_source};
use crate::ffi::{ItemKind, OutlineItem};

const MODULE: &str = "buf";

pub fn from_source(text: &str) -> Option<Vec<OutlineItem>> {
    let items = extract_source(text, &context(), &[MODULE.into()]).ok()?;
    Some(outline(items))
}

pub fn from_tree(tree: &Tree, text: &str) -> Vec<OutlineItem> {
    outline(extract_parsed(
        tree.root_node(),
        text,
        &context(),
        &[MODULE.into()],
    ))
}

fn context() -> CrateContext {
    CrateContext {
        crate_name: MODULE.into(),
        crate_version: "0.0.0".into(),
        crate_root: Path::new("<mem>").to_path_buf(),
        edition: None,
        features: Vec::new(),
        scope: Scope::Workspace,
    }
}

fn outline(items: Vec<ItemDoc>) -> Vec<OutlineItem> {
    items
        .into_iter()
        .filter(|i| {
            matches!(
                i.item_kind,
                ItemKind::Struct
                    | ItemKind::Enum
                    | ItemKind::Union
                    | ItemKind::Trait
                    | ItemKind::Fn
                    | ItemKind::Method
                    | ItemKind::Mod
                    | ItemKind::Type
                    | ItemKind::Const
                    | ItemKind::Static
                    | ItemKind::Macro
            )
        })
        .map(|i| OutlineItem {
            name: i.name,
            kind: i.item_kind,
            start_byte: i.byte_range.0,
            end_byte: i.byte_range.1,
            name_start_byte: i.name_start_byte,
            signature: i.signature,
            doc: i.doc_first_paragraph,
        })
        .collect()
}
