use tree_sitter::{Node, Tree};

use crate::ffi::ByteRange;

use super::grammar::Grammar;
use super::walk::each_node;

const SCOPE_KINDS: &[&str] = &[
    "function_item",
    "closure_expression",
    "function_definition",
    "lambda_expression",
];

pub fn occurrences(tree: &Tree, text: &str, byte: u32, grammar: &Grammar) -> Vec<ByteRange> {
    let Some(node) = ident_at(tree, byte) else {
        return Vec::new();
    };
    let Ok(name) = node.utf8_text(text.as_bytes()) else {
        return Vec::new();
    };
    if name.is_empty() {
        return Vec::new();
    }
    let Some(scope) = enclosing_scope(node) else {
        return Vec::new();
    };
    if !declared_in(scope, text, name, grammar) {
        return Vec::new();
    }
    collect(scope, text, name)
}

fn ident_at<'a>(tree: &'a Tree, byte: u32) -> Option<Node<'a>> {
    let byte = byte as usize;
    exact(tree, byte).or_else(|| byte.checked_sub(1).and_then(|b| exact(tree, b)))
}

fn exact<'a>(tree: &'a Tree, byte: usize) -> Option<Node<'a>> {
    let node = tree.root_node().descendant_for_byte_range(byte, byte)?;
    (node.kind() == "identifier").then_some(node)
}

fn enclosing_scope<'a>(node: Node<'a>) -> Option<Node<'a>> {
    let mut current = node.parent();
    while let Some(n) = current {
        if SCOPE_KINDS.contains(&n.kind()) {
            return Some(n);
        }
        current = n.parent();
    }
    None
}

fn declared_in(scope: Node<'_>, text: &str, name: &str, grammar: &Grammar) -> bool {
    let mut found = false;
    each_node(scope, &mut |node| {
        if found || node.kind() != "identifier" {
            return;
        }
        if node.utf8_text(text.as_bytes()) == Ok(name) && (grammar.declares)(node, text) {
            found = true;
        }
    });
    found
}

fn collect(scope: Node<'_>, text: &str, name: &str) -> Vec<ByteRange> {
    let mut out = Vec::new();
    each_node(scope, &mut |node| {
        if node.kind() != "identifier" {
            return;
        }
        if node.utf8_text(text.as_bytes()) == Ok(name) {
            out.push(ByteRange {
                start_byte: node.start_byte() as u32,
                end_byte: node.end_byte() as u32,
            });
        }
    });
    out.sort_by_key(|r| r.start_byte);
    out
}
