use tree_sitter::{Node, Tree};

use crate::highlight::rust_type_names::enclosing_impl;

use super::common::{
    PositionWords, head_before, in_open_comment, inside, path_segments, position, word_start,
};
use super::{Site, SiteAt, use_path};

const NO_COMPLETION: &[&str] = &[
    "line_comment",
    "block_comment",
    "string_literal",
    "raw_string_literal",
    "char_literal",
    "string_content",
    "escape_sequence",
];

const WORDS: PositionWords = PositionWords {
    types: &[
        "as", "impl", "dyn", "struct", "enum", "trait", "type", "where",
    ],
    values: &["return", "in", "if", "while", "match", "else"],
    type_symbols: &[":", "->", "<"],
    value_symbols: &[
        "=", "(", ",", "{", ";", "+", "-", "*", "/", "!", "==", "!=", "<=", ">=", "&&", "||", "=>",
        "[", "|",
    ],
    transparent: &["&", "mut"],
};

pub fn rust(tree: Option<&Tree>, text: &str, at: usize) -> SiteAt {
    let start = word_start(text, at, &[]);
    let prefix = text[start..at].to_string();
    let probe = if prefix.is_empty() { at } else { start + 1 };
    if inside(tree, probe, NO_COMPLETION) || in_open_comment(text, start) {
        return SiteAt::none(at);
    }
    let head = head_before(text, start);
    let site = if let Some(derive) = attribute(head) {
        Site::Attribute { derive }
    } else if let Some(segments) = use_path::parse(head) {
        Site::UsePath(segments)
    } else if head.ends_with("::") {
        Site::ScopedPath(path_segments(head).0)
    } else if head.ends_with('.') && !head.ends_with("..") {
        Site::MemberAccess
    } else if let Some(name) = struct_literal(tree, head, at) {
        Site::StructLiteral(name)
    } else {
        Site::Identifier(position(head, &WORDS))
    };
    SiteAt::new(site, prefix, start, text, at)
}

fn attribute(head: &str) -> Option<bool> {
    let open = head.rfind("#[").max(head.rfind("#!["))?;
    let inner = &head[open..];
    if inner.contains(']') {
        return None;
    }
    let derive = inner
        .find("derive(")
        .is_some_and(|i| !inner[i + 7..].contains(')'));
    Some(derive)
}

fn struct_literal(tree: Option<&Tree>, head: &str, at: usize) -> Option<String> {
    if !(head.ends_with('{') || head.ends_with(',')) {
        return None;
    }
    let tree = tree?;
    let probe = at.saturating_sub(1);
    let mut node = tree.root_node().descendant_for_byte_range(probe, probe)?;
    for _ in 0..6 {
        if node.kind() == "field_initializer_list" {
            return struct_name(node.parent()?, head);
        }
        node = node.parent()?;
    }
    None
}

fn struct_name(expr: Node<'_>, text: &str) -> Option<String> {
    if expr.kind() != "struct_expression" {
        return None;
    }
    let name = expr.child_by_field_name("name")?;
    let full = &text[name.start_byte()..name.end_byte().min(text.len())];
    let base = full.rsplit("::").next().unwrap_or(full);
    if base == "Self" {
        return enclosing_impl(expr, text);
    }
    Some(base.to_string())
}
