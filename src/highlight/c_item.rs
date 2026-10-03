use tree_sitter::Node;

use crate::ffi::{ItemKind, OutlineItem};

use super::c_docs;
use super::c_names::node_text;

pub fn item(node: Node<'_>, name: Node<'_>, kind: ItemKind, text: &str) -> Option<OutlineItem> {
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
        signature: c_docs::signature(node, text),
        doc: c_docs::doc(node, text),
        scope: None,
    })
}

pub fn named(node: Node<'_>, kind: ItemKind, text: &str) -> Option<OutlineItem> {
    item(node, node.child_by_field_name("name")?, kind, text)
}
