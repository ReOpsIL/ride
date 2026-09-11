use tree_sitter::Node;

use crate::ffi::ByteRange;

pub fn range(root: Node<'_>, byte: u32, is_statement: fn(&str) -> bool) -> Option<ByteRange> {
    Some(bytes(node_at(root, byte, is_statement)?))
}

pub fn sibling(
    root: Node<'_>,
    byte: u32,
    up: bool,
    is_statement: fn(&str) -> bool,
) -> Option<ByteRange> {
    let node = node_at(root, byte, is_statement)?;
    let parent = node.parent()?;
    let mut cursor = parent.walk();
    let sibs: Vec<Node<'_>> = parent
        .named_children(&mut cursor)
        .filter(|child| is_statement(child.kind()))
        .collect();
    let i = sibs.iter().position(|child| child.id() == node.id())?;
    let target = if up {
        sibs.get(i.checked_sub(1)?)
    } else {
        sibs.get(i + 1)
    }?;
    Some(bytes(*target))
}

pub fn rust(kind: &str) -> bool {
    matches!(
        kind,
        "expression_statement"
            | "let_declaration"
            | "use_declaration"
            | "extern_crate_declaration"
            | "macro_definition"
            | "associated_type"
    ) || (kind.ends_with("_item") && !matches!(kind, "attribute_item" | "inner_attribute_item"))
}

pub fn c(kind: &str) -> bool {
    kind.ends_with("_statement")
        || matches!(
            kind,
            "declaration" | "function_definition" | "for_range_loop"
        )
}

pub fn none(_: &str) -> bool {
    false
}

fn node_at<'a>(root: Node<'a>, byte: u32, is_statement: fn(&str) -> bool) -> Option<Node<'a>> {
    let at = (byte as usize).min(root.end_byte());
    let mut node = root.descendant_for_byte_range(at, at).or(Some(root));
    while let Some(n) = node {
        if is_statement(n.kind()) {
            return Some(n);
        }
        node = n.parent();
    }
    None
}

fn bytes(node: Node<'_>) -> ByteRange {
    ByteRange {
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
    }
}
