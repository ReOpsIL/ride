use tree_sitter::Node;

use crate::ffi::{ItemKind, OutlineItem};
use crate::text::first_line;

use super::symbol::node_text;

pub fn line_item(
    node: Node<'_>,
    name: Node<'_>,
    kind: ItemKind,
    text: &str,
) -> Option<OutlineItem> {
    let label = node_text(name, text);
    if label.is_empty() {
        return None;
    }
    Some(OutlineItem {
        name: label,
        kind,
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
        name_start_byte: name.start_byte() as u32,
        signature: first_line(&node_text(node, text)),
        doc: String::new(),
    })
}
