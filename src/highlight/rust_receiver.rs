use tree_sitter::{Node, Tree};

use super::rust_type_names::{enclosing_impl, expr_type, type_name};
use super::rust_types::field_type;
use super::symbol::node_text;
use super::walk::each_node;

const MAX_CHAIN: usize = 4;
const FN_SCOPES: &[&str] = &[
    "function_item",
    "function_signature_item",
    "closure_expression",
];

pub fn receiver_type(tree: &Tree, text: &str, receiver: Node<'_>) -> Option<String> {
    resolve(tree, text, receiver, 0)
}

fn resolve(tree: &Tree, text: &str, node: Node<'_>, depth: usize) -> Option<String> {
    if depth > MAX_CHAIN {
        return None;
    }
    let found = match node.kind() {
        "self" => enclosing_impl(node, text),
        "identifier" => declared(tree, text, node, depth),
        "field_identifier" => field_chain(tree, text, node, depth),
        _ => None,
    }?;
    if found == "Self" {
        enclosing_impl(node, text)
    } else {
        Some(found)
    }
}

fn field_chain(tree: &Tree, text: &str, field: Node<'_>, depth: usize) -> Option<String> {
    let parent = field.parent().filter(|p| p.kind() == "field_expression")?;
    if parent.child_by_field_name("field")?.id() != field.id() {
        return None;
    }
    let value = parent.child_by_field_name("value")?;
    let owner = value_type(tree, text, value, depth + 1)?;
    field_type(tree, text, &owner, &node_text(field, text))
}

fn value_type(tree: &Tree, text: &str, value: Node<'_>, depth: usize) -> Option<String> {
    match value.kind() {
        "self" | "identifier" => resolve(tree, text, value, depth),
        "field_expression" => value
            .child_by_field_name("field")
            .and_then(|f| resolve(tree, text, f, depth)),
        _ => expr_type(value, text),
    }
}

fn declared(tree: &Tree, text: &str, ident: Node<'_>, depth: usize) -> Option<String> {
    let name = node_text(ident, text);
    let at = ident.start_byte();
    let mut best: Option<((bool, usize), Node<'_>)> = None;
    each_node(tree.root_node(), &mut |node| {
        if node.start_byte() >= at || !declares(node, text, &name) {
            return;
        }
        let in_scope = scope_of(node).is_some_and(|s| s.start_byte() <= at && at <= s.end_byte());
        let key = (in_scope, node.start_byte());
        if best.is_none_or(|(prev, _)| prev < key) {
            best = Some((key, node));
        }
    });
    let (_, decl) = best?;
    declared_type(tree, text, decl, depth)
}

fn declares(node: Node<'_>, text: &str, name: &str) -> bool {
    match node.kind() {
        "let_declaration" | "parameter" | "for_expression" => node
            .child_by_field_name("pattern")
            .is_some_and(|p| binds(p, text, name)),
        "identifier" => {
            node.parent()
                .is_some_and(|p| p.kind() == "closure_parameters")
                && node_text(node, text) == name
        }
        _ => false,
    }
}

fn binds(pattern: Node<'_>, text: &str, name: &str) -> bool {
    match pattern.kind() {
        "identifier" => node_text(pattern, text) == name,
        "mut_pattern" | "ref_pattern" => {
            let mut cursor = pattern.walk();
            pattern
                .named_children(&mut cursor)
                .any(|c| binds(c, text, name))
        }
        _ => false,
    }
}

fn scope_of(decl: Node<'_>) -> Option<Node<'_>> {
    match decl.kind() {
        "let_declaration" => decl.parent(),
        "for_expression" => Some(decl),
        "identifier" => decl.parent()?.parent(),
        _ => {
            let mut current = decl.parent();
            while let Some(parent) = current {
                if FN_SCOPES.contains(&parent.kind()) {
                    return Some(parent);
                }
                current = parent.parent();
            }
            None
        }
    }
}

fn declared_type(tree: &Tree, text: &str, decl: Node<'_>, depth: usize) -> Option<String> {
    if let Some(ty) = decl.child_by_field_name("type") {
        return type_name(ty, text);
    }
    if decl.kind() != "let_declaration" {
        return None;
    }
    let value = decl.child_by_field_name("value")?;
    value_type(tree, text, value, depth + 1)
}
