use std::path::Path;

use crate::extract::{CrateContext, Scope, extract_source};
use crate::ffi::{ItemKind, OutlineItem};

pub fn from_source(text: &str) -> Option<Vec<OutlineItem>> {
    let ctx = CrateContext {
        crate_name: "buf".into(),
        crate_version: "0.0.0".into(),
        crate_root: Path::new("<mem>").to_path_buf(),
        edition: None,
        features: Vec::new(),
        scope: Scope::Workspace,
    };
    let items = extract_source(text, &ctx, &["buf".into()]).ok()?;
    let outline: Vec<OutlineItem> = items
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
        .collect();
    Some(outline)
}
