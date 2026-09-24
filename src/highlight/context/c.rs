use tree_sitter::{Node, Tree};

use super::scan::{brace_depth, statement_or_expression};
use super::{Context, ancestors, node_at};
use crate::highlight::site::{c_type_position, word_start};
use crate::text::line_start;

pub fn c(tree: Option<&Tree>, text: &str, at: usize) -> Context {
    let start = word_start(text, at, &[]);
    if on_directive_line(text, start) {
        return Context::Preprocessor;
    }
    let ctx = node_at(tree, start, at)
        .and_then(|node| ancestors(node).find_map(|n| classify(n, text, start)))
        .unwrap_or_else(|| fallback(text, start));
    typed(ctx, text, start)
}

fn typed(ctx: Context, text: &str, start: usize) -> Context {
    let loose = matches!(
        ctx,
        Context::Item | Context::Statement | Context::Expression
    );
    if loose && c_type_position(text[..start].trim_end()) {
        Context::Type
    } else {
        ctx
    }
}

fn on_directive_line(text: &str, start: usize) -> bool {
    let head = &text[..start];
    let line_start = line_start(head, head.len());
    head[line_start..].trim_start().starts_with('#')
}

fn classify(node: Node<'_>, text: &str, start: usize) -> Option<Context> {
    let head = &text[node.start_byte().min(start)..start];
    let ctx = match node.kind() {
        "preproc_include"
        | "preproc_def"
        | "preproc_function_def"
        | "preproc_call"
        | "preproc_arg"
        | "preproc_params" => {
            if head.contains('\n') {
                return None;
            }
            Context::Preprocessor
        }
        "field_declaration_list" | "enumerator_list" => Context::Fields,
        "compound_statement" => switch_or_block(node, text, start),
        "case_statement" => case_label(node, text),
        "initializer_list" if function_body(node) => statement_or_expression(text, start),
        "translation_unit"
        | "declaration_list"
        | "template_declaration"
        | "linkage_specification" => Context::Item,
        "parameter_list"
        | "template_parameter_list"
        | "template_argument_list"
        | "type_descriptor"
        | "base_class_clause"
        | "trailing_return_type" => Context::Type,
        "argument_list"
        | "initializer_list"
        | "condition_clause"
        | "parenthesized_expression"
        | "return_statement"
        | "assignment_expression"
        | "binary_expression"
        | "call_expression"
        | "subscript_expression"
        | "for_range_loop" => Context::Expression,
        "declaration" | "field_declaration" => {
            if head.trim().is_empty() {
                return None;
            }
            if head.contains('=') {
                Context::Expression
            } else {
                Context::Type
            }
        }
        "class_specifier" | "struct_specifier" | "union_specifier" | "enum_specifier"
            if past_keyword(node, start) =>
        {
            Context::Type
        }
        "function_definition" | "function_declarator" | "abstract_function_declarator"
            if start > node.start_byte() =>
        {
            Context::Type
        }
        _ => return None,
    };
    Some(ctx)
}

const SPECIFIER_KEYWORDS: &[&str] = &["class", "struct", "union", "enum"];

fn past_keyword(node: Node<'_>, start: usize) -> bool {
    let mut cursor = node.walk();
    node.children(&mut cursor)
        .find(|child| SPECIFIER_KEYWORDS.contains(&child.kind()))
        .is_some_and(|keyword| start > keyword.end_byte())
}

fn function_body(node: Node<'_>) -> bool {
    node.parent()
        .filter(|parent| parent.kind() == "init_declarator")
        .and_then(|parent| parent.child_by_field_name("declarator"))
        .is_some_and(|declarator| declarator.kind() == "function_declarator")
}

fn switch_or_block(node: Node<'_>, text: &str, start: usize) -> Context {
    if node
        .parent()
        .is_some_and(|p| p.kind() == "switch_statement")
    {
        Context::Case
    } else {
        statement_or_expression(text, start)
    }
}

fn case_label(node: Node<'_>, text: &str) -> Context {
    let start = node.start_byte();
    let end = node.end_byte().min(text.len());
    if text[start..end].trim_start().starts_with("default") {
        Context::Default
    } else {
        Context::Case
    }
}

fn fallback(text: &str, start: usize) -> Context {
    if brace_depth(&text[..start]) == 0 {
        Context::Item
    } else {
        statement_or_expression(text, start)
    }
}
