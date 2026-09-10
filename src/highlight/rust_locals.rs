use tree_sitter::Node;

use crate::text::collapse_ws;

use super::locals::within_field;

const PATTERN_OWNERS: &[&str] = &[
    "let_declaration",
    "parameter",
    "for_expression",
    "match_arm",
];

const TYPED_OWNERS: &[&str] = &["let_declaration", "parameter"];

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

pub fn detail(node: Node<'_>, text: &str) -> Option<String> {
    let mut owner = node.parent()?;
    if matches!(owner.kind(), "mut_pattern" | "ref_pattern") {
        owner = owner.parent()?;
    }
    if !TYPED_OWNERS.contains(&owner.kind()) || !within_field(owner, "pattern", node) {
        return None;
    }
    let ty = owner.child_by_field_name("type")?;
    Some(collapse_ws(ty.utf8_text(text.as_bytes()).ok()?))
}
