use std::collections::HashSet;

use tree_sitter::{Node, Tree};

use crate::ffi::{CalleeHit, OutlineItem};

use super::symbol::node_text;
use super::walk::each_node;

const CALL_KINDS: &[&str] = &["call_expression", "method_call_expression"];

pub fn collect(tree: &Tree, text: &str, outline: &[OutlineItem], byte: u32) -> Vec<CalleeHit> {
    let Some((start, end)) = enclosing(outline, byte) else {
        return Vec::new();
    };
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    each_node(tree.root_node(), &mut |node| {
        if !CALL_KINDS.contains(&node.kind()) {
            return;
        }
        let at = node.start_byte() as u32;
        if at < start || at >= end {
            return;
        }
        let Some(name_node) = callee_name(node) else {
            return;
        };
        let name = node_text(name_node, text);
        if name.is_empty() || !seen.insert(name.clone()) {
            return;
        }
        out.push(CalleeHit {
            name,
            byte_start: name_node.start_byte() as u32,
            byte_end: name_node.end_byte() as u32,
            line: name_node.start_position().row as u32 + 1,
        });
    });
    out
}

fn enclosing(outline: &[OutlineItem], byte: u32) -> Option<(u32, u32)> {
    outline
        .iter()
        .filter(|o| o.start_byte <= byte && byte < o.end_byte)
        .min_by_key(|o| o.end_byte - o.start_byte)
        .map(|o| (o.start_byte, o.end_byte))
}

fn callee_name(node: Node<'_>) -> Option<Node<'_>> {
    let target = node
        .child_by_field_name("function")
        .or_else(|| node.child_by_field_name("method"))?;
    leaf(target)
}

fn leaf(node: Node<'_>) -> Option<Node<'_>> {
    match node.kind() {
        "identifier" | "field_identifier" | "type_identifier" | "primitive_type" => Some(node),
        "field_expression" => leaf(node.child_by_field_name("field")?),
        "scoped_identifier" | "qualified_identifier" | "template_function" | "template_method" => {
            leaf(node.child_by_field_name("name")?)
        }
        "generic_function" => leaf(node.child_by_field_name("function")?),
        _ => None,
    }
}
