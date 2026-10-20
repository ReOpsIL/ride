use tree_sitter::{Node, Tree};

use crate::ffi::SymbolAt;

pub fn symbol_at(
    tree: &Tree,
    text: &str,
    byte: u32,
    kinds: &[&str],
    qualifier: fn(Node<'_>, &str) -> Option<String>,
) -> Option<SymbolAt> {
    symbol_node(tree, byte, kinds).map(|node| SymbolAt {
        name: node_text(node, text),
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
        qualifier: qualifier(node, text),
    })
}

pub fn symbol_node<'a>(tree: &'a Tree, byte: u32, kinds: &[&str]) -> Option<Node<'a>> {
    let byte = byte as usize;
    node_at(tree, byte, kinds)
        .or_else(|| byte.checked_sub(1).and_then(|b| node_at(tree, b, kinds)))
        .filter(|node| !in_lifetime(*node))
}

fn node_at<'a>(tree: &'a Tree, byte: usize, kinds: &[&str]) -> Option<Node<'a>> {
    let node = ident_node(tree, byte, kinds)?;
    (!in_lifetime(node)).then_some(node)
}

fn in_lifetime(node: Node<'_>) -> bool {
    std::iter::successors(Some(node), |n| n.parent())
        .take(6)
        .any(|n| n.kind() == "lifetime")
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

pub fn name_start_byte(node: Node<'_>, name: &str, text: &str) -> u32 {
    let mut cur = node.child_by_field_name("name");
    while let Some(n) = cur {
        match n.child_by_field_name("name") {
            Some(inner) => cur = Some(inner),
            None => return n.start_byte() as u32,
        }
    }
    let start = node.start_byte();
    let end = node.end_byte().min(text.len());
    text.get(start..end)
        .and_then(|s| s.find(name))
        .map(|i| (start + i) as u32)
        .unwrap_or(start as u32)
}
