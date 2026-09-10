use serde::{Deserialize, Serialize};
use tree_sitter::{Node, Tree};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct IncludeRef {
    pub name: String,
    pub quoted: bool,
}

const SCOPES: &[&str] = &[
    "translation_unit",
    "preproc_if",
    "preproc_ifdef",
    "preproc_else",
    "preproc_elif",
    "preproc_elifdef",
    "linkage_specification",
    "declaration_list",
];

pub fn c_includes(tree: &Tree, text: &str) -> Vec<IncludeRef> {
    let mut out = Vec::new();
    walk(tree.root_node(), text, &mut out);
    out
}

pub fn no_includes(_: &Tree, _: &str) -> Vec<IncludeRef> {
    Vec::new()
}

fn walk(node: Node<'_>, text: &str, out: &mut Vec<IncludeRef>) {
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        match child.kind() {
            "preproc_include" => out.extend(include_ref(child, text)),
            k if SCOPES.contains(&k) => walk(child, text, out),
            _ => {}
        }
    }
}

fn include_ref(node: Node<'_>, text: &str) -> Option<IncludeRef> {
    let path = node.child_by_field_name("path")?;
    let raw = path.utf8_text(text.as_bytes()).ok()?.trim();
    match path.kind() {
        "string_literal" => Some(IncludeRef {
            name: raw.trim_matches('"').to_string(),
            quoted: true,
        }),
        "system_lib_string" => Some(IncludeRef {
            name: raw
                .trim_start_matches('<')
                .trim_end_matches('>')
                .to_string(),
            quoted: false,
        }),
        _ => None,
    }
}
