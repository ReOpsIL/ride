use tree_sitter::{Node, Tree};

use super::c_names::{SPECIFIERS, WRAPPERS, node_text, plain_name, type_name, wrapped};
use super::walk::each_node;

const DECLARATIONS: &[&str] = &[
    "declaration",
    "parameter_declaration",
    "optional_parameter_declaration",
    "field_declaration",
];

pub fn receiver_type(tree: &Tree, text: &str, receiver: Node<'_>) -> Option<String> {
    if receiver.kind() == "this" {
        return enclosing_type(receiver, text);
    }
    if receiver.kind() != "identifier" {
        return None;
    }
    let name = node_text(receiver, text);
    let at = receiver.start_byte();
    let mut before: Option<(usize, Node<'_>)> = None;
    let mut first: Option<Node<'_>> = None;
    each_node(tree.root_node(), &mut |node| {
        if !DECLARATIONS.contains(&node.kind()) || !declares(node, text, &name) {
            return;
        }
        let Some(ty) = node.child_by_field_name("type") else {
            return;
        };
        first.get_or_insert(ty);
        if node.start_byte() < at && before.is_none_or(|(b, _)| node.start_byte() > b) {
            before = Some((node.start_byte(), ty));
        }
    });
    let ty = before.map(|(_, ty)| ty).or(first)?;
    type_name(ty, text)
}

fn declares(node: Node<'_>, text: &str, name: &str) -> bool {
    let mut cursor = node.walk();
    node.children_by_field_name("declarator", &mut cursor)
        .any(|d| plain_name(d, text).as_deref() == Some(name))
}

fn enclosing_type(node: Node<'_>, text: &str) -> Option<String> {
    let mut current = node.parent();
    while let Some(parent) = current {
        if SPECIFIERS.contains(&parent.kind()) {
            return parent
                .child_by_field_name("name")
                .map(|n| node_text(n, text));
        }
        if parent.kind() == "function_definition"
            && let Some(scope) = definition_scope(parent, text)
        {
            return Some(scope);
        }
        current = parent.parent();
    }
    None
}

fn definition_scope(definition: Node<'_>, text: &str) -> Option<String> {
    let mut node = definition.child_by_field_name("declarator")?;
    while WRAPPERS.contains(&node.kind()) {
        node = wrapped(node)?;
    }
    let inner = node.child_by_field_name("declarator")?;
    if inner.kind() != "qualified_identifier" {
        return None;
    }
    let scope = inner.child_by_field_name("scope")?;
    type_name(scope, text).or_else(|| Some(node_text(scope, text)))
}

pub fn no_receiver(_: &Tree, _: &str, _: Node<'_>) -> Option<String> {
    None
}
