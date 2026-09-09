use tree_sitter::Node;

use super::item::node_text;

pub fn type_as_written(node: Node<'_>, source: &str) -> String {
    match node.kind() {
        "type_identifier" | "primitive_type" => node_text(node, source),
        "scoped_type_identifier" => strip_angles(&collapse(&node_text(node, source))),
        "generic_type" | "reference_type" | "pointer_type" => node
            .child_by_field_name("type")
            .map(|t| type_as_written(t, source))
            .unwrap_or_default(),
        "dynamic_type" | "abstract_type" => node
            .child_by_field_name("trait")
            .map(|t| type_as_written(t, source))
            .unwrap_or_default(),
        _ => {
            if let Some(id) = first_kind(node, "type_identifier") {
                if has_kind(node, "scoped_type_identifier") {
                    return strip_angles(&collapse(&node_text(node, source)));
                }
                return node_text(id, source);
            }
            if let Some(id) = first_kind(node, "primitive_type") {
                return node_text(id, source);
            }
            strip_angles(&collapse(&node_text(node, source)))
        }
    }
}

fn first_kind<'a>(node: Node<'a>, kind: &str) -> Option<Node<'a>> {
    if node.kind() == kind {
        return Some(node);
    }
    for i in 0..node.named_child_count() {
        if let Some(child) = super::ts::child_at(node, i)
            && let Some(n) = first_kind(child, kind)
        {
            return Some(n);
        }
    }
    None
}

fn has_kind(node: Node<'_>, kind: &str) -> bool {
    if node.kind() == kind {
        return true;
    }
    for i in 0..node.named_child_count() {
        if let Some(child) = super::ts::child_at(node, i)
            && has_kind(child, kind)
        {
            return true;
        }
    }
    false
}

fn collapse(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn strip_angles(s: &str) -> String {
    let mut out = String::new();
    let mut depth = 0u32;
    for c in s.chars() {
        match c {
            '<' => depth += 1,
            '>' => depth = depth.saturating_sub(1),
            _ if depth == 0 => out.push(c),
            _ => {}
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}
