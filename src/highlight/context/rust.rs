use tree_sitter::{Node, Tree};

use super::scan::{brace_depth, statement_or_expression};
use super::{Context, ancestors, node_at};
use crate::highlight::site::{rust_type_position, word_start};

pub fn rust(tree: Option<&Tree>, text: &str, at: usize) -> Context {
    let start = word_start(text, at, &[]);
    if statement_head(text, start).starts_with("use ") {
        return Context::Use;
    }
    let ctx = node_at(tree, start, at)
        .and_then(|node| from_tree(node, text, start))
        .unwrap_or_else(|| fallback(text, start));
    typed(ctx, text, start)
}

fn typed(ctx: Context, text: &str, start: usize) -> Context {
    let loose = matches!(
        ctx,
        Context::Item | Context::Statement | Context::Expression
    );
    if loose && rust_type_position(text[..start].trim_end()) {
        Context::Type
    } else {
        ctx
    }
}

fn from_tree(node: Node<'_>, text: &str, start: usize) -> Option<Context> {
    ancestors(node).find_map(|n| classify(n, text, start))
}

fn classify(node: Node<'_>, text: &str, start: usize) -> Option<Context> {
    let head = &text[node.start_byte().min(start)..start];
    let ctx = match node.kind() {
        "attribute_item" | "inner_attribute_item" => Context::Attribute,
        "use_declaration" => Context::Use,
        "match_block" => match_block(text, start),
        "match_arm" if !head.contains("=>") => Context::Case,
        "let_declaration" => let_declaration(head),
        "parameters" | "closure_parameters" | "type_parameters" | "type_arguments"
        | "where_clause" | "trait_bounds" => Context::Type,
        "declaration_list" => match node.parent().map(|p| p.kind()) {
            Some("impl_item" | "trait_item") => Context::Body,
            _ => Context::Item,
        },
        "field_declaration_list" | "enum_variant_list" | "ordered_field_declaration_list" => {
            Context::Fields
        }
        "block" | "unsafe_block" | "async_block" | "const_block" => in_block(text, start),
        "function_item"
        | "function_signature_item"
        | "impl_item"
        | "trait_item"
        | "struct_item"
        | "enum_item"
        | "type_item"
        | "union_item" => Context::Type,
        "const_item" | "static_item" => {
            if head.contains('=') {
                Context::Expression
            } else {
                Context::Type
            }
        }
        "source_file" => Context::Item,
        _ => return None,
    };
    Some(ctx)
}

fn statement_head(text: &str, start: usize) -> &str {
    let head = &text[..start];
    let stmt_start = head.rfind([';', '{', '}']).map(|i| i + 1).unwrap_or(0);
    head[stmt_start..].trim_start()
}

fn in_block(text: &str, start: usize) -> Context {
    match statement_head(text, start).strip_prefix("let ") {
        Some(rest) => let_declaration(rest),
        None => statement_or_expression(text, start),
    }
}

fn match_block(text: &str, start: usize) -> Context {
    let head = text[..start].trim_end();
    if head.ends_with(['{', ',', '}']) {
        Context::Case
    } else {
        Context::Expression
    }
}

fn let_declaration(head: &str) -> Context {
    if head.contains('=') {
        Context::Expression
    } else if head.contains(':') {
        Context::Type
    } else {
        Context::Pattern
    }
}

fn fallback(text: &str, start: usize) -> Context {
    if brace_depth(&text[..start]) == 0 {
        Context::Item
    } else {
        statement_or_expression(text, start)
    }
}
