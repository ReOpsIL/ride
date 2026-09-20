use tree_sitter::Node;

use crate::highlight::symbol::node_text;
use crate::highlight::walk::each_node;
use crate::text::is_word;

const SCOPES: &[&str] = &["function_item", "closure_expression", "source_file"];

pub fn scrutinee_type(node: Node<'_>, text: &str) -> Option<String> {
    let name = base_identifier(node.child_by_field_name("value")?, text)?;
    let scope = enclosing_scope(node)?;
    let mut found = None;
    each_node(scope, &mut |current| {
        if found.is_none() {
            found = declared_type(current, text, &name);
        }
    });
    found
}

pub fn enclosing_indent(text: &str, at: usize) -> String {
    let start = text
        .get(..at)
        .and_then(|head| head.rfind('\n').map(|i| i + 1))
        .unwrap_or(0);
    text.get(start..at)
        .unwrap_or_default()
        .chars()
        .take_while(|c| c.is_whitespace())
        .collect()
}

fn base_identifier(node: Node<'_>, text: &str) -> Option<String> {
    let mut current = node;
    while matches!(
        current.kind(),
        "reference_expression" | "parenthesized_expression" | "unary_expression"
    ) {
        current = current.named_child(0)?;
    }
    (current.kind() == "identifier").then(|| node_text(current, text))
}

fn enclosing_scope(node: Node<'_>) -> Option<Node<'_>> {
    let mut current = Some(node);
    while let Some(n) = current {
        if SCOPES.contains(&n.kind()) {
            return Some(n);
        }
        current = n.parent();
    }
    None
}

fn declared_type(node: Node<'_>, text: &str, name: &str) -> Option<String> {
    match node.kind() {
        "let_declaration" => {
            let pattern = node.child_by_field_name("pattern")?;
            if node_text(pattern, text) != name {
                return None;
            }
            match node.child_by_field_name("type") {
                Some(ty) => type_name(&node_text(ty, text)),
                None => value_type(node.child_by_field_name("value")?, text),
            }
        }
        "parameter" => {
            let pattern = node.child_by_field_name("pattern")?;
            if node_text(pattern, text) != name {
                return None;
            }
            type_name(&node_text(node.child_by_field_name("type")?, text))
        }
        _ => None,
    }
}

fn value_type(value: Node<'_>, text: &str) -> Option<String> {
    let path = match value.kind() {
        "call_expression" => value.child_by_field_name("function")?,
        "scoped_identifier" => value,
        _ => return None,
    };
    if path.kind() != "scoped_identifier" {
        return None;
    }
    let raw = node_text(path, text);
    let mut segments = raw.split("::");
    let owner = segments.next()?;
    segments.next()?;
    type_name(owner)
}

fn type_name(raw: &str) -> Option<String> {
    let trimmed = raw.trim().trim_start_matches(['&', '*']).trim();
    let head = trimmed
        .split(['<', ' '])
        .next()
        .unwrap_or(trimmed)
        .rsplit("::")
        .next()
        .unwrap_or(trimmed);
    let name: String = head.chars().take_while(|c| is_word(*c)).collect();
    (!name.is_empty()).then_some(name)
}
