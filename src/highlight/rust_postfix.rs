use tree_sitter::Tree;

const EXPRESSIONS: &[&str] = &[
    "identifier",
    "self",
    "field_expression",
    "call_expression",
    "index_expression",
    "parenthesized_expression",
    "reference_expression",
    "unary_expression",
    "try_expression",
    "await_expression",
    "macro_invocation",
    "string_literal",
    "raw_string_literal",
    "integer_literal",
    "float_literal",
    "boolean_literal",
    "char_literal",
    "array_expression",
    "tuple_expression",
    "struct_expression",
    "scoped_identifier",
    "generic_function",
    "binary_expression",
    "range_expression",
];

pub fn receiver(tree: &Tree, text: &str, replace_start: usize) -> Option<(usize, usize)> {
    let head = text[..replace_start].trim_end();
    let dot = head.strip_suffix('.')?.len();
    if dot == 0 {
        return None;
    }
    let mut node = tree
        .root_node()
        .named_descendant_for_byte_range(dot - 1, dot - 1)?;
    while node.end_byte() == dot && !EXPRESSIONS.contains(&node.kind()) {
        node = node.parent()?;
    }
    if node.end_byte() != dot {
        return None;
    }
    while let Some(parent) = node.parent() {
        if parent.end_byte() != dot || !EXPRESSIONS.contains(&parent.kind()) {
            break;
        }
        node = parent;
    }
    Some((node.start_byte(), dot))
}
