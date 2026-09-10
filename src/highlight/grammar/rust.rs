use tree_sitter::{Language, Node, Tree};

use crate::ffi::OutlineItem;

use super::Grammar;
use crate::highlight::editing::{EditingKinds, rust_folds};
use crate::highlight::members::{Chain, Root};
use crate::highlight::symbol::node_text;
use crate::highlight::{context, imports, includes, rust_outline, rust_receiver, rust_types, site};

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
        declares: crate::highlight::rust_locals::declares,
        local_detail: crate::highlight::rust_locals::detail,
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
        receiver: receiver_chain,
        type_table: rust_types::build,
        includes: includes::no_includes,
        site: site::rust_site,
        context: context::rust_context,
        imports: imports::rust_imports,
        editing: EditingKinds {
            strings: &["string_literal", "raw_string_literal", "char_literal"],
            comments: &["line_comment", "block_comment"],
            bodies: &[
                "block",
                "declaration_list",
                "field_declaration_list",
                "enum_variant_list",
                "match_block",
            ],
            folds: rust_folds,
        },
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

fn receiver_chain(tree: &Tree, text: &str, node: Node<'_>) -> Option<Chain> {
    let leaf = match node.kind() {
        "field_expression" => node.child_by_field_name("field")?,
        "identifier" | "self" | "field_identifier" => node,
        _ => return None,
    };
    rust_receiver::receiver_type(tree, text, leaf).map(|t| Chain::root(Root::Type(t)))
}
