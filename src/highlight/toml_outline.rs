use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};
use crate::text::first_line;

use super::c_names::node_text;

const KEYS: &[&str] = &["bare_key", "dotted_key", "quoted_key"];

pub fn outline(tree: &Tree, text: &str) -> Vec<OutlineItem> {
    let root = tree.root_node();
    let mut cursor = root.walk();
    root.named_children(&mut cursor)
        .filter(|n| matches!(n.kind(), "table" | "table_array_element"))
        .filter_map(|n| table(n, text))
        .collect()
}

fn table(node: Node<'_>, text: &str) -> Option<OutlineItem> {
    let mut cursor = node.walk();
    let key = node
        .named_children(&mut cursor)
        .find(|c| KEYS.contains(&c.kind()))?;
    Some(OutlineItem {
        name: node_text(key, text),
        kind: ItemKind::Table,
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
        name_start_byte: key.start_byte() as u32,
        signature: first_line(&node_text(node, text)),
        doc: String::new(),
    })
}
