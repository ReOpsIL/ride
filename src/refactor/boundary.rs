use tree_sitter::Node;

use super::tree::field_of;

const BODY_KINDS: [&str; 2] = ["block", "compound_statement"];

const CONDITIONAL_PARENTS: [&str; 5] = [
    "closure_expression",
    "lambda_expression",
    "match_arm",
    "else_clause",
    "case_statement",
];

pub fn unconditional_statement(node: Node<'_>) -> Option<Node<'_>> {
    let mut current = node;
    while let Some(parent) = current.parent() {
        if BODY_KINDS.contains(&parent.kind()) {
            return Some(current);
        }
        if crosses_condition(parent, current) {
            return None;
        }
        current = parent;
    }
    None
}

fn crosses_condition(parent: Node<'_>, child: Node<'_>) -> bool {
    if CONDITIONAL_PARENTS.contains(&parent.kind()) {
        return true;
    }
    let field = field_of(child);
    match parent.kind() {
        "binary_expression" => field == Some("right") && short_circuit(parent),
        "let_chain" => parent
            .named_child(0)
            .is_some_and(|first| first.id() != child.id()),
        "while_expression" | "while_statement" | "do_statement" => {
            matches!(field, Some("condition" | "body"))
        }
        "for_statement" => matches!(field, Some("condition" | "update" | "body")),
        "for_expression" | "for_range_loop" => field == Some("body"),
        "if_statement" => matches!(field, Some("consequence" | "alternative")),
        "conditional_expression" => matches!(field, Some("consequence" | "alternative")),
        _ => false,
    }
}

fn short_circuit(binary: Node<'_>) -> bool {
    binary
        .child_by_field_name("operator")
        .is_some_and(|op| matches!(op.kind(), "&&" | "||"))
}
