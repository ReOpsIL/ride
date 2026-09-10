use tree_sitter::Node;

use crate::text::collapse_ws;

use super::c_names::{node_text, wrapped};
use super::locals::within_field;

pub const DECLARATIONS: &[&str] = &[
    "declaration",
    "parameter_declaration",
    "optional_parameter_declaration",
    "field_declaration",
];

const SKIPPED: &[&str] = &[
    "storage_class_specifier",
    "attribute_specifier",
    "attribute_declaration",
];

pub fn declares_local(node: Node<'_>, _: &str) -> bool {
    owner(node).is_some()
}

pub fn detail(node: Node<'_>, text: &str) -> Option<String> {
    let owner = owner(node)?;
    let mut cursor = owner.walk();
    let declarator = owner
        .children_by_field_name("declarator", &mut cursor)
        .find(|d| d.start_byte() <= node.start_byte() && node.end_byte() <= d.end_byte())?;
    declared_type(owner, declarator, text)
}

pub fn declared_type(owner: Node<'_>, declarator: Node<'_>, text: &str) -> Option<String> {
    let base = base_type(owner, text)?;
    Some(decorate(base, declarator, text))
}

fn owner(node: Node<'_>) -> Option<Node<'_>> {
    let mut current = node;
    for _ in 0..4 {
        let parent = current.parent()?;
        if DECLARATIONS.contains(&parent.kind()) {
            return within_field(parent, "declarator", node).then_some(parent);
        }
        current = parent;
    }
    None
}

fn base_type(owner: Node<'_>, text: &str) -> Option<String> {
    let end = owner.child_by_field_name("declarator")?.start_byte();
    let mut cursor = owner.walk();
    let start = owner
        .named_children(&mut cursor)
        .filter(|c| c.start_byte() < end && !SKIPPED.contains(&c.kind()))
        .map(|c| c.start_byte())
        .min()?;
    let base = collapse_ws(text.get(start..end)?);
    (!base.is_empty()).then_some(base)
}

fn decorate(base: String, declarator: Node<'_>, text: &str) -> String {
    let mut stars = String::new();
    let mut suffix = String::new();
    let mut current = declarator;
    loop {
        let inner = match current.kind() {
            "pointer_declarator" => {
                stars.push('*');
                wrapped(current)
            }
            "reference_declarator" => {
                stars.push_str(&reference_token(current, text));
                wrapped(current)
            }
            "array_declarator" => {
                let inner = current.child_by_field_name("declarator");
                if let Some(i) = inner
                    && let Some(dims) = text.get(i.end_byte()..current.end_byte())
                {
                    suffix.insert_str(0, dims.trim());
                }
                inner
            }
            "init_declarator" | "attributed_declarator" | "parenthesized_declarator" => current
                .child_by_field_name("declarator")
                .or_else(|| wrapped(current)),
            _ => None,
        };
        let Some(inner) = inner else {
            break;
        };
        current = inner;
    }
    let mut out = base;
    if !stars.is_empty() {
        out.push(' ');
        out.push_str(&stars);
    }
    out.push_str(&suffix);
    out
}

fn reference_token(node: Node<'_>, text: &str) -> String {
    node.child(0)
        .filter(|c| matches!(c.kind(), "&" | "&&"))
        .map(|c| node_text(c, text))
        .unwrap_or_else(|| "&".to_string())
}
