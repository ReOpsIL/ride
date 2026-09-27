use tree_sitter::{Node, Tree};

use super::c_names::{SPECIFIERS, WRAPPERS, node_text, plain_name, type_name, wrapped};
use super::walk::each_node;

const DECLARATIONS: &[&str] = &[
    "declaration",
    "parameter_declaration",
    "optional_parameter_declaration",
    "field_declaration",
    "for_range_loop",
];

pub enum Declared<'a> {
    Type(String),
    Init(Node<'a>),
}

pub fn declared<'a>(tree: &'a Tree, text: &str, ident: Node<'_>) -> Option<Declared<'a>> {
    let name = node_text(ident, text);
    let at = ident.start_byte();
    let mut visible: Option<Node<'a>> = None;
    let mut before: Option<Node<'a>> = None;
    let mut first: Option<Node<'a>> = None;
    each_node(tree.root_node(), &mut |node| {
        if !DECLARATIONS.contains(&node.kind()) || !declares(node, text, &name) {
            return;
        }
        first.get_or_insert(node);
        if node.start_byte() >= at {
            return;
        }
        let later = |b: Node<'_>| node.start_byte() > b.start_byte();
        if before.is_none_or(later) {
            before = Some(node);
        }
        if in_scope(node, at) && visible.is_none_or(later) {
            visible = Some(node);
        }
    });
    let declaration = visible.or(before).or(first)?;
    let ty = declaration.child_by_field_name("type")?;
    if is_auto(ty, text) {
        return initializer(declaration, text, &name).map(Declared::Init);
    }
    type_name(ty, text).map(Declared::Type)
}

const SCOPES: &[&str] = &[
    "compound_statement",
    "for_statement",
    "for_range_loop",
    "function_definition",
    "lambda_expression",
    "field_declaration_list",
    "declaration_list",
    "translation_unit",
];

fn in_scope(declaration: Node<'_>, at: usize) -> bool {
    let parameter = declaration.kind().ends_with("parameter_declaration");
    let mut current = if declaration.kind() == "for_range_loop" {
        Some(declaration)
    } else {
        declaration.parent()
    };
    while let Some(scope) = current {
        let kind = scope.kind();
        let owns = SCOPES.contains(&kind)
            && (!parameter || matches!(kind, "function_definition" | "lambda_expression"));
        if owns {
            return scope.start_byte() <= at && at <= scope.end_byte();
        }
        current = scope.parent();
    }
    true
}

fn is_auto(ty: Node<'_>, text: &str) -> bool {
    ty.kind() == "placeholder_type_specifier" || node_text(ty, text) == "auto"
}

fn initializer<'a>(declaration: Node<'a>, text: &str, name: &str) -> Option<Node<'a>> {
    let mut cursor = declaration.walk();
    declaration
        .children_by_field_name("declarator", &mut cursor)
        .find(|d| plain_name(*d, text).as_deref() == Some(name))
        .and_then(|d| d.child_by_field_name("value"))
}

fn declares(node: Node<'_>, text: &str, name: &str) -> bool {
    let mut cursor = node.walk();
    node.children_by_field_name("declarator", &mut cursor)
        .any(|d| plain_name(d, text).as_deref() == Some(name))
}

pub fn enclosing_type(node: Node<'_>, text: &str) -> Option<String> {
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

pub fn declares_local(node: Node<'_>, _: &str) -> bool {
    let mut current = node;
    for _ in 0..4 {
        let Some(parent) = current.parent() else {
            return false;
        };
        if DECLARATIONS.contains(&parent.kind()) {
            return super::locals::within_field(parent, "declarator", node);
        }
        current = parent;
    }
    false
}
