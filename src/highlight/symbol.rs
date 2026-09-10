use tree_sitter::{Node, Tree};

use crate::ffi::SymbolAt;

pub fn symbol_at(
    tree: &Tree,
    text: &str,
    byte: u32,
    kinds: &[&str],
    qualifier: fn(Node<'_>, &str) -> Option<String>,
) -> Option<SymbolAt> {
    let byte = byte as usize;
    ident_node(tree, byte, kinds)
        .or_else(|| byte.checked_sub(1).and_then(|b| ident_node(tree, b, kinds)))
        .map(|node| SymbolAt {
            name: node_text(node, text),
            start_byte: node.start_byte() as u32,
            end_byte: node.end_byte() as u32,
            qualifier: qualifier(node, text),
        })
}

fn ident_node<'a>(tree: &'a Tree, byte: usize, kinds: &[&str]) -> Option<Node<'a>> {
    let node = tree.root_node().descendant_for_byte_range(byte, byte)?;
    kinds.contains(&node.kind()).then_some(node)
}

pub fn node_text(node: Node<'_>, text: &str) -> String {
    node.utf8_text(text.as_bytes())
        .unwrap_or_default()
        .to_string()
}
