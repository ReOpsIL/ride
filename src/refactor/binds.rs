use tree_sitter::Node;

use crate::highlight::walk::each_node;

use super::tree::field_of;

pub enum Rebinding<'t> {
    Clear,
    Whole,
    Only(Vec<Node<'t>>),
}

pub fn binds(pattern: Node<'_>, text: &str, wanted: &impl Fn(&str) -> bool) -> bool {
    let mut hit = false;
    each_node(pattern, &mut |node| {
        if hit || !matches!(node.kind(), "identifier" | "shorthand_field_identifier") {
            return;
        }
        let path = node
            .parent()
            .is_some_and(|p| p.kind() == "scoped_identifier");
        if !path
            && field_of(node) != Some("type")
            && node.utf8_text(text.as_bytes()).is_ok_and(wanted)
        {
            hit = true;
        }
    });
    hit
}

pub fn rebinding<'t>(node: Node<'t>, text: &str, wanted: &impl Fn(&str) -> bool) -> Rebinding<'t> {
    let field_binds = |field: &str| {
        node.child_by_field_name(field)
            .is_some_and(|p| binds(p, text, wanted))
    };
    match node.kind() {
        "function_item" | "function_definition" => Rebinding::Whole,
        "closure_expression" if field_binds("parameters") => Rebinding::Whole,
        "lambda_expression" if field_binds("declarator") => Rebinding::Whole,
        "match_arm" if field_binds("pattern") => Rebinding::Whole,
        "for_expression" if field_binds("pattern") => {
            Rebinding::Only(node.child_by_field_name("value").into_iter().collect())
        }
        "if_expression" | "while_expression" => conditional_rebinding(node, text, wanted),
        _ => Rebinding::Clear,
    }
}

pub fn shadowed(
    node: Node<'_>,
    root: Node<'_>,
    text: &str,
    wanted: &impl Fn(&str) -> bool,
) -> bool {
    let mut current = node;
    while let Some(parent) = current.parent() {
        if parent.id() == root.id() {
            return false;
        }
        match rebinding(parent, text, wanted) {
            Rebinding::Whole => return true,
            Rebinding::Only(open) if !open.iter().any(|o| contains(*o, node)) => return true,
            _ => {}
        }
        current = parent;
    }
    false
}

pub fn contains(outer: Node<'_>, inner: Node<'_>) -> bool {
    outer.start_byte() <= inner.start_byte() && inner.end_byte() <= outer.end_byte()
}

fn conditional_rebinding<'t>(
    node: Node<'t>,
    text: &str,
    wanted: &impl Fn(&str) -> bool,
) -> Rebinding<'t> {
    let Some(condition) = node.child_by_field_name("condition") else {
        return Rebinding::Clear;
    };
    let mut open = Vec::new();
    let mut rebinds = false;
    each_node(condition, &mut |n| {
        if n.kind() == "let_condition" {
            rebinds |= n
                .child_by_field_name("pattern")
                .is_some_and(|p| binds(p, text, wanted));
            open.extend(n.child_by_field_name("value"));
        }
    });
    if !rebinds {
        return Rebinding::Clear;
    }
    open.extend(node.child_by_field_name("alternative"));
    Rebinding::Only(open)
}
