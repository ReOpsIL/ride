use tree_sitter::Node;

use crate::highlight::walk::each_node;

use super::binds::{binds, shadowed};
use super::declare::Declaration;
use super::uses::is_use;

pub fn mutated_in(scope: Node<'_>, text: &str, wanted: &impl Fn(&str) -> bool) -> bool {
    mutated_between(scope, (scope.start_byte(), scope.end_byte()), text, wanted)
}

pub fn disturbed(decl: &Declaration<'_>, uses: &[Node<'_>], text: &str) -> bool {
    let names = value_names(decl.value, text);
    let (Some(region), Some(last)) = (decl.statement.parent(), uses.last()) else {
        return false;
    };
    if names.is_empty() {
        return false;
    }
    let wanted = |t: &str| names.iter().any(|n| n == t);
    let span = (decl.statement.end_byte(), last.end_byte());
    mutated_between(region, span, text, &wanted)
        || rebound_between(region, span, text, &wanted)
        || uses.iter().any(|u| shadowed(*u, region, text, &wanted))
}

fn value_names(value: Node<'_>, text: &str) -> Vec<String> {
    let mut names = Vec::new();
    each_node(value, &mut |node| {
        if node.kind() == "identifier"
            && is_use(node)
            && let Ok(name) = node.utf8_text(text.as_bytes())
        {
            names.push(name.to_string());
        }
    });
    names
}

fn mutated_between(
    region: Node<'_>,
    (start, end): (usize, usize),
    text: &str,
    wanted: &impl Fn(&str) -> bool,
) -> bool {
    let mut hit = false;
    each_node(region, &mut |node| {
        if hit || node.start_byte() < start || node.start_byte() >= end {
            return;
        }
        hit = mutation_target(node)
            .and_then(root_ident)
            .and_then(|ident| ident.utf8_text(text.as_bytes()).ok())
            .is_some_and(wanted);
    });
    hit
}

fn rebound_between(
    region: Node<'_>,
    (start, end): (usize, usize),
    text: &str,
    wanted: &impl Fn(&str) -> bool,
) -> bool {
    let mut hit = false;
    each_node(region, &mut |node| {
        if hit || node.start_byte() < start || node.start_byte() >= end {
            return;
        }
        let field = match node.kind() {
            "let_declaration" => "pattern",
            "declaration" => "declarator",
            _ => return,
        };
        let mut cursor = node.walk();
        hit = node
            .children_by_field_name(field, &mut cursor)
            .any(|p| binds(p, text, wanted));
    });
    hit
}

fn mutation_target(node: Node<'_>) -> Option<Node<'_>> {
    match node.kind() {
        "assignment_expression" | "compound_assignment_expr" => node.child_by_field_name("left"),
        "update_expression" => node.child_by_field_name("argument"),
        "reference_expression" if has_child(node, "mutable_specifier") => {
            node.child_by_field_name("value")
        }
        "pointer_expression" if has_child(node, "&") => node.child_by_field_name("argument"),
        _ => None,
    }
}

fn has_child(node: Node<'_>, kind: &str) -> bool {
    let mut cursor = node.walk();
    node.children(&mut cursor).any(|c| c.kind() == kind)
}

fn root_ident(expr: Node<'_>) -> Option<Node<'_>> {
    let mut current = expr;
    loop {
        current = match current.kind() {
            "identifier" => return Some(current),
            "field_expression" => current
                .child_by_field_name("value")
                .or_else(|| current.child_by_field_name("argument"))?,
            "subscript_expression" => current.child_by_field_name("argument")?,
            "index_expression" | "parenthesized_expression" => current.named_child(0)?,
            "unary_expression" | "pointer_expression" => current
                .child_by_field_name("argument")
                .or_else(|| current.named_child(0))?,
            _ => return None,
        };
    }
}
