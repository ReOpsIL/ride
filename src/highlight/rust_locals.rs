use tree_sitter::Node;

use super::locals::within_field;

const PATTERN_OWNERS: &[&str] = &[
    "let_declaration",
    "parameter",
    "for_expression",
    "match_arm",
];

pub fn declares(node: Node<'_>, _: &str) -> bool {
    let mut current = node;
    for _ in 0..4 {
        let Some(parent) = current.parent() else {
            return false;
        };
        if parent.kind() == "closure_parameters" {
            return true;
        }
        if PATTERN_OWNERS.contains(&parent.kind()) {
            return within_field(parent, "pattern", node);
        }
        current = parent;
    }
    false
}
