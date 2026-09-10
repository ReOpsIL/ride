use tree_sitter::{Node, Tree};

use super::c_decls::{Declared, declared, enclosing_type};
use super::c_names::{node_text, plain_name, type_name};
use super::members::{Chain, MAX_CHAIN, Root, Step};

const CASTS: &[&str] = &[
    "static_cast",
    "dynamic_cast",
    "reinterpret_cast",
    "const_cast",
];

const TRANSPARENT: &[&str] = &[
    "subscript_expression",
    "pointer_expression",
    "parenthesized_expression",
    "unary_expression",
];

pub fn receiver_chain(tree: &Tree, text: &str, expr: Node<'_>) -> Option<Chain> {
    chain(tree, text, expr, 0)
}

fn chain(tree: &Tree, text: &str, expr: Node<'_>, depth: usize) -> Option<Chain> {
    if depth > MAX_CHAIN {
        return None;
    }
    match expr.kind() {
        "identifier" => match declared(tree, text, expr)? {
            Declared::Type(name) => Some(Chain::root(Root::Type(name))),
            Declared::Init(value) => chain(tree, text, value, depth + 1),
        },
        "this" => enclosing_type(expr, text).map(|t| Chain::root(Root::Type(t))),
        "field_expression" => {
            let argument = expr.child_by_field_name("argument")?;
            let field = plain_name(expr.child_by_field_name("field")?, text)?;
            chain(tree, text, argument, depth + 1)?.then(Step::Field(field))
        }
        "call_expression" => call(tree, text, expr, depth),
        "cast_expression" | "compound_literal_expression" | "new_expression" => expr
            .child_by_field_name("type")
            .and_then(|t| type_name(t, text))
            .map(|t| Chain::root(Root::Type(t))),
        kind if TRANSPARENT.contains(&kind) => {
            let inner = expr
                .child_by_field_name("argument")
                .or_else(|| expr.named_child(0))?;
            chain(tree, text, inner, depth + 1)
        }
        _ => None,
    }
}

fn call(tree: &Tree, text: &str, expr: Node<'_>, depth: usize) -> Option<Chain> {
    let function = expr.child_by_field_name("function")?;
    match function.kind() {
        "identifier" => Some(Chain::root(Root::Call(node_text(function, text)))),
        "field_expression" => {
            let argument = function.child_by_field_name("argument")?;
            let field = plain_name(function.child_by_field_name("field")?, text)?;
            chain(tree, text, argument, depth + 1)?.then(Step::Call(field))
        }
        "qualified_identifier" => {
            let scope = function.child_by_field_name("scope")?;
            let name = plain_name(function.child_by_field_name("name")?, text)?;
            let owner = type_name(scope, text).unwrap_or_else(|| node_text(scope, text));
            Chain::root(Root::Type(owner)).then(Step::Call(name))
        }
        "template_function" => {
            let name = node_text(function.child_by_field_name("name")?, text);
            if CASTS.contains(&name.as_str()) {
                let args = function.child_by_field_name("arguments")?;
                let target = args.named_child(0).and_then(|t| type_name(t, text))?;
                return Some(Chain::root(Root::Type(target)));
            }
            Some(Chain::root(Root::Call(name)))
        }
        _ => None,
    }
}
