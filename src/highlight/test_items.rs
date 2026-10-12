use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};
use crate::text::collapse_ws;

pub fn missing(tree: &Tree, text: &str, have: &[OutlineItem]) -> Vec<OutlineItem> {
    let mut out = Vec::new();
    walk(tree.root_node(), text, have, &mut out);
    out
}

fn walk(node: Node<'_>, text: &str, have: &[OutlineItem], out: &mut Vec<OutlineItem>) {
    if node.kind() == "function_item"
        && !have
            .iter()
            .any(|item| item.start_byte == node.start_byte() as u32)
        && let Some(item) = function(node, text)
    {
        out.push(item);
    }
    let mut index = 0u32;
    while let Some(child) = node.named_child(index) {
        walk(child, text, have, out);
        index += 1;
    }
}

fn function(node: Node<'_>, text: &str) -> Option<OutlineItem> {
    let name_node = node.child_by_field_name("name")?;
    let name = text
        .get(name_node.start_byte()..name_node.end_byte())?
        .to_string();
    let end = node.end_byte() as u32;
    let start = node.start_byte() as u32;
    let signature_end = node
        .child_by_field_name("body")
        .map(|body| body.start_byte())
        .unwrap_or(node.end_byte());
    let signature = text
        .get(node.start_byte()..signature_end)
        .map(|slice| collapse_ws(slice.trim().trim_end_matches('{')))
        .unwrap_or_default();
    Some(OutlineItem {
        name,
        kind: ItemKind::Fn,
        start_byte: start,
        end_byte: end,
        name_start_byte: name_node.start_byte() as u32,
        signature,
        doc: String::new(),
        scope: None,
    })
}
