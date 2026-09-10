use tree_sitter::Node;

use super::symbol::node_text;

const STRING_METHODS: &[&str] = &["to_string", "to_uppercase", "to_lowercase"];

pub fn type_name(node: Node<'_>, text: &str) -> Option<String> {
    match node.kind() {
        "type_identifier" | "primitive_type" => Some(node_text(node, text)),
        "scoped_type_identifier" => child_type(node, "name", text),
        "generic_type" | "reference_type" | "pointer_type" => child_type(node, "type", text),
        "dynamic_type" | "abstract_type" => child_type(node, "trait", text),
        "bounded_type" => node.named_child(0).and_then(|n| type_name(n, text)),
        _ => None,
    }
}

pub fn expr_type(node: Node<'_>, text: &str) -> Option<String> {
    match node.kind() {
        "call_expression" => node
            .child_by_field_name("function")
            .and_then(|f| call_type(f, text)),
        "struct_expression" => node
            .child_by_field_name("name")
            .and_then(|n| constructor(n, text)),
        "macro_invocation" => macro_type(node, text),
        "string_literal" | "raw_string_literal" => Some("str".into()),
        "integer_literal" => Some("i32".into()),
        "float_literal" => Some("f64".into()),
        "boolean_literal" => Some("bool".into()),
        "char_literal" => Some("char".into()),
        "reference_expression" => node
            .child_by_field_name("value")
            .and_then(|v| expr_type(v, text)),
        "parenthesized_expression" => node.named_child(0).and_then(|v| expr_type(v, text)),
        "type_cast_expression" => child_type(node, "type", text),
        _ => None,
    }
}

pub fn enclosing_impl(node: Node<'_>, text: &str) -> Option<String> {
    let mut current = node.parent();
    while let Some(parent) = current {
        if parent.kind() == "impl_item" {
            return type_name(parent.child_by_field_name("type")?, text);
        }
        current = parent.parent();
    }
    None
}

pub fn constructor(path: Node<'_>, text: &str) -> Option<String> {
    let base = match path.kind() {
        "identifier" | "type_identifier" => node_text(path, text),
        "scoped_identifier" | "scoped_type_identifier" => {
            node_text(path.child_by_field_name("name")?, text)
        }
        "generic_type" | "generic_type_with_turbofish" => {
            return path
                .child_by_field_name("type")
                .and_then(|t| constructor(t, text));
        }
        _ => return None,
    };
    base.chars()
        .next()
        .filter(char::is_ascii_uppercase)
        .map(|_| base)
}

fn child_type(node: Node<'_>, field: &str, text: &str) -> Option<String> {
    node.child_by_field_name(field)
        .and_then(|n| type_name(n, text))
}

fn call_type(function: Node<'_>, text: &str) -> Option<String> {
    match function.kind() {
        "scoped_identifier" => function
            .child_by_field_name("path")
            .and_then(|p| constructor(p, text)),
        "generic_function" => function
            .child_by_field_name("function")
            .and_then(|f| call_type(f, text)),
        "field_expression" => {
            let method = node_text(function.child_by_field_name("field")?, text);
            STRING_METHODS
                .contains(&method.as_str())
                .then(|| "String".to_string())
        }
        _ => None,
    }
}

fn macro_type(node: Node<'_>, text: &str) -> Option<String> {
    let name = node_text(node.child_by_field_name("macro")?, text);
    match name.rsplit("::").next().unwrap_or(&name) {
        "vec" => Some("Vec".into()),
        "format" => Some("String".into()),
        _ => None,
    }
}
