use tree_sitter::Node;

use crate::ffi::ByteRange;
use crate::highlight::walk::each_node;
use crate::text::names_inline_arg;

use super::binds::{binds, shadowed};
use super::declare::{Declaration, is_named};
use super::tree::{field_of, has_ancestor};

const NON_USE_FIELDS: [&str; 9] = [
    "macro",
    "name",
    "type",
    "pattern",
    "declarator",
    "label",
    "path",
    "field",
    "parameters",
];

const ATOMIC_KINDS: [&str; 26] = [
    "identifier",
    "integer_literal",
    "float_literal",
    "string_literal",
    "raw_string_literal",
    "char_literal",
    "boolean_literal",
    "number_literal",
    "true",
    "false",
    "null",
    "this",
    "self",
    "field_expression",
    "call_expression",
    "method_call_expression",
    "index_expression",
    "subscript_expression",
    "parenthesized_expression",
    "tuple_expression",
    "array_expression",
    "struct_expression",
    "macro_invocation",
    "scoped_identifier",
    "try_expression",
    "await_expression",
];

const STANDALONE_PARENTS: [&str; 12] = [
    "arguments",
    "argument_list",
    "token_tree",
    "expression_statement",
    "return_expression",
    "array_expression",
    "tuple_expression",
    "field_initializer",
    "initializer_list",
    "parenthesized_expression",
    "block",
    "compound_statement",
];

pub struct InlineUse {
    pub range: ByteRange,
    pub parenthesize: bool,
    pub shorthand: bool,
}

pub fn use_nodes<'t>(decl: &Declaration<'t>, text: &str, name: &str) -> Option<Vec<Node<'t>>> {
    let region = decl.statement.parent()?;
    let after = decl.statement.end_byte();
    let is_name = |t: &str| t == name;
    let mut found = Vec::new();
    let mut refused = false;
    each_node(region, &mut |node| {
        if refused || node.start_byte() < after {
            return;
        }
        match node.kind() {
            "let_declaration" => {
                refused = node
                    .child_by_field_name("pattern")
                    .is_some_and(|p| binds(p, text, &is_name));
            }
            "string_literal" | "raw_string_literal" => {
                refused = has_ancestor(node, &["token_tree"])
                    && node
                        .utf8_text(text.as_bytes())
                        .is_ok_and(|t| names_inline_arg(t, name));
            }
            "identifier"
                if is_named(node, text, name)
                    && is_use(node)
                    && !shadowed(node, region, text, &is_name) =>
            {
                found.push(node);
            }
            _ => {}
        }
    });
    (!refused).then_some(found)
}

pub fn inline_use(node: Node<'_>, value: Node<'_>) -> InlineUse {
    let shorthand = node
        .parent()
        .is_some_and(|p| p.kind() == "shorthand_field_initializer");
    InlineUse {
        range: ByteRange {
            start_byte: node.start_byte() as u32,
            end_byte: node.end_byte() as u32,
        },
        parenthesize: !shorthand && !ATOMIC_KINDS.contains(&value.kind()) && !standalone(node),
        shorthand,
    }
}

pub fn is_use(node: Node<'_>) -> bool {
    let Some(parent) = node.parent() else {
        return false;
    };
    let kind = parent.kind();
    if matches!(
        kind,
        "scoped_identifier" | "use_as_clause" | "use_list" | "scoped_use_list"
    ) || kind.ends_with("_pattern")
    {
        return false;
    }
    !field_of(node).is_some_and(|f| NON_USE_FIELDS.contains(&f))
}

fn standalone(node: Node<'_>) -> bool {
    let Some(parent) = node.parent() else {
        return true;
    };
    let field = field_of(node);
    match parent.kind() {
        kind if STANDALONE_PARENTS.contains(&kind) => true,
        "assignment_expression" => field == Some("right"),
        "let_declaration" | "init_declarator" => field == Some("value"),
        "for_expression" => field == Some("value"),
        _ => false,
    }
}
