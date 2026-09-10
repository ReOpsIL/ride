use tree_sitter::{Language, Node, Tree};

use crate::ffi::OutlineItem;

use super::Grammar;
use crate::highlight::symbol::node_text;
use crate::highlight::{c_members, includes, rust_outline, types};

const HIGHLIGHTS: &str = include_str!("../../../queries/rust/highlights.scm");

pub const KEYWORDS: &[&str] = &[
    "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
    "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
    "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type",
    "unsafe", "use", "where", "while",
];

pub fn grammar() -> Grammar {
    Grammar {
        language: Language::new(tree_sitter_rust::LANGUAGE),
        highlights: HIGHLIGHTS,
        keywords: KEYWORDS,
        local_kinds: &["identifier", "type_identifier"],
        symbol_kinds: &[
            "identifier",
            "type_identifier",
            "field_identifier",
            "primitive_type",
        ],
        qualifier,
        outline,
        member_ops: &["."],
        member_kinds: &["field_identifier"],
        receiver_type: c_members::no_receiver,
        type_table: types::empty_table,
        includes: includes::no_includes,
    }
}

fn outline(_: &Tree, text: &str) -> Vec<OutlineItem> {
    rust_outline::from_source(text).unwrap_or_default()
}

fn qualifier(node: Node<'_>, text: &str) -> Option<String> {
    let parent = node.parent()?;
    if !matches!(
        parent.kind(),
        "scoped_identifier" | "scoped_type_identifier"
    ) {
        return None;
    }
    let name = parent.child_by_field_name("name")?;
    if name.id() != node.id() {
        return None;
    }
    parent
        .child_by_field_name("path")
        .map(|p| node_text(p, text))
        .filter(|q| !q.is_empty())
}
