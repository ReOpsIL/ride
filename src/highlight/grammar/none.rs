use tree_sitter::{Node, Tree};

pub fn no_qualifier(_: Node<'_>, _: &str) -> Option<String> {
    None
}

pub fn no_postfix(_: &Tree, _: &str, _: usize) -> Option<(usize, usize)> {
    None
}
