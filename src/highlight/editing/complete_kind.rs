use tree_sitter::Node;

pub fn header_without_body(node: Node<'_>) -> bool {
    if node.is_error() {
        return header_error(node);
    }
    match node.kind() {
        "if_expression" | "if_statement" => missing_field(node, "consequence"),
        "for_expression"
        | "while_expression"
        | "for_statement"
        | "while_statement"
        | "for_range_loop"
        | "function_item"
        | "function_definition" => missing_field(node, "body"),
        "function_signature_item" => true,
        "declaration" => c_fn_decl(node) && semi_hole(node).is_some(),
        _ => false,
    }
}

pub fn header_end(node: Node<'_>) -> u32 {
    let mut end = node.start_byte();
    for i in 0..node.child_count() {
        let Some(child) = node.child(i) else {
            continue;
        };
        if child.is_missing() || empty_body(child) {
            continue;
        }
        end = child.end_byte();
    }
    end as u32
}

pub fn missing_semi(node: Node<'_>) -> Option<u32> {
    if !wants_semi(node) {
        return None;
    }
    semi_hole(node)
}

fn semi_hole(node: Node<'_>) -> Option<u32> {
    (0..node.child_count())
        .filter_map(|i| node.child(i))
        .find(|c| c.is_missing() && c.kind() == ";")
        .map(|c| c.start_byte() as u32)
}

pub fn bare_expr(node: Node<'_>) -> bool {
    let Some(parent) = node.parent() else {
        return false;
    };
    is_block(parent.kind())
        && (value_expr(node.kind()) || node.is_error() && !header_without_body(node))
}

fn header_error(node: Node<'_>) -> bool {
    let Some(first) = (0..node.child_count())
        .filter_map(|i| node.child(i))
        .find(|c| !c.is_missing())
    else {
        return false;
    };
    matches!(first.kind(), "if" | "for" | "while" | "fn") && !has_brace(node)
}

fn has_brace(node: Node<'_>) -> bool {
    (0..node.child_count()).any(|i| {
        node.child(i)
            .is_some_and(|c| matches!(c.kind(), "{" | "block" | "compound_statement"))
    })
}

fn missing_field(node: Node<'_>, field: &str) -> bool {
    node.child_by_field_name(field).is_none_or(empty_body)
}

fn empty_body(node: Node<'_>) -> bool {
    if node.is_missing() {
        return true;
    }
    node.kind() == "expression_statement"
        && (0..node.child_count()).all(|i| node.child(i).is_none_or(|c| c.is_missing()))
}

fn wants_semi(node: Node<'_>) -> bool {
    match node.kind() {
        "let_declaration"
        | "expression_statement"
        | "use_declaration"
        | "extern_crate_declaration"
        | "return_statement"
        | "break_expression"
        | "continue_expression" => true,
        "declaration" => !c_fn_decl(node),
        _ => false,
    }
}

fn c_fn_decl(node: Node<'_>) -> bool {
    let mut cur = node.child_by_field_name("declarator");
    while let Some(n) = cur {
        if n.kind() == "function_declarator" {
            return true;
        }
        cur = n.child_by_field_name("declarator");
    }
    false
}

fn is_block(kind: &str) -> bool {
    matches!(kind, "block" | "compound_statement")
}

fn value_expr(kind: &str) -> bool {
    !is_block(kind)
        && !kind.ends_with("_statement")
        && !kind.ends_with("_item")
        && !kind.ends_with("_declaration")
        && !matches!(
            kind,
            "declaration"
                | "function_definition"
                | "function_signature_item"
                | "ERROR"
                | "source_file"
                | "translation_unit"
        )
}
