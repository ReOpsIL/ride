use tree_sitter::Node;

use crate::ffi::ByteRange;
use crate::highlight::walk::each_node;

use super::capture::{disturbed, mutated_in};
use super::declare::declaration;
use super::uses::{InlineUse, inline_use, use_nodes};

const SCOPE_KINDS: [&str; 4] = [
    "function_item",
    "closure_expression",
    "function_definition",
    "lambda_expression",
];

const SIDE_EFFECT_KINDS: [&str; 3] = [
    "call_expression",
    "method_call_expression",
    "macro_invocation",
];

pub struct InlineSpans {
    pub name: ByteRange,
    pub statement: ByteRange,
    pub init: ByteRange,
    pub uses: Vec<InlineUse>,
}

pub fn inline_spans(root: Node<'_>, text: &str, byte: u32) -> Option<InlineSpans> {
    let ident = ident_at(root, byte)?;
    let name = ident.utf8_text(text.as_bytes()).ok()?;
    if name.is_empty() {
        return None;
    }
    let scope = enclosing_scope(ident)?;
    if mutated_in(scope, text, &|t: &str| t == name) {
        return None;
    }
    let decl = declaration(scope, text, name)?;
    if has_side_effects(decl.value) {
        return None;
    }
    let nodes = use_nodes(&decl, text, name)?;
    if nodes.is_empty() || disturbed(&decl, &nodes, text) {
        return None;
    }
    Some(InlineSpans {
        name: range_of(decl.name),
        statement: range_of(decl.statement),
        init: range_of(decl.value),
        uses: nodes.iter().map(|n| inline_use(*n, decl.value)).collect(),
    })
}

fn range_of(node: Node<'_>) -> ByteRange {
    ByteRange {
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
    }
}

fn ident_at<'a>(root: Node<'a>, byte: u32) -> Option<Node<'a>> {
    let byte = byte as usize;
    exact(root, byte).or_else(|| byte.checked_sub(1).and_then(|b| exact(root, b)))
}

fn exact<'a>(root: Node<'a>, byte: usize) -> Option<Node<'a>> {
    let node = root.descendant_for_byte_range(byte, byte)?;
    (node.kind() == "identifier").then_some(node)
}

fn enclosing_scope(node: Node<'_>) -> Option<Node<'_>> {
    let mut current = node.parent();
    while let Some(n) = current {
        if SCOPE_KINDS.contains(&n.kind()) {
            return Some(n);
        }
        current = n.parent();
    }
    None
}

fn has_side_effects(value: Node<'_>) -> bool {
    let mut hit = false;
    each_node(value, &mut |node| {
        hit |= SIDE_EFFECT_KINDS.contains(&node.kind());
    });
    hit
}
