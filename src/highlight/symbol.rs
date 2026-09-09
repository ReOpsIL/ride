use tree_sitter::{Node, Tree};

use crate::ffi::SymbolAt;

const IDENT_KINDS: [&str; 4] = [
    "identifier",
    "type_identifier",
    "field_identifier",
    "primitive_type",
];

pub fn symbol_at(tree: &Tree, text: &str, byte: u32) -> Option<SymbolAt> {
    let byte = byte as usize;
    ident_node(tree, byte)
        .or_else(|| byte.checked_sub(1).and_then(|b| ident_node(tree, b)))
        .map(|node| SymbolAt {
            name: node_text(node, text),
            start_byte: node.start_byte() as u32,
            end_byte: node.end_byte() as u32,
            qualifier: qualifier(node, text),
        })
}

fn ident_node(tree: &Tree, byte: usize) -> Option<Node<'_>> {
    let node = tree.root_node().descendant_for_byte_range(byte, byte)?;
    IDENT_KINDS.contains(&node.kind()).then_some(node)
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

fn node_text(node: Node<'_>, text: &str) -> String {
    node.utf8_text(text.as_bytes())
        .unwrap_or_default()
        .to_string()
}
