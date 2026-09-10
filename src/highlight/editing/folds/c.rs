use tree_sitter::{Node, Tree};

use crate::ffi::FoldRange;
use crate::highlight::walk::each_node;

use super::lines::{between, braced, closed, finish, last_content, runs, span};

const BODIES: &[(&str, &str)] = &[
    ("function_definition", "fn"),
    ("struct_specifier", "struct"),
    ("union_specifier", "struct"),
    ("class_specifier", "class"),
    ("enum_specifier", "enum"),
    ("namespace_definition", "namespace"),
];

pub fn folds(tree: &Tree, text: &str) -> Vec<FoldRange> {
    let mut out = Vec::new();
    let mut comments = Vec::new();
    let mut includes = Vec::new();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        "compound_statement" => {
            if node
                .parent()
                .is_none_or(|p| p.kind() != "function_definition")
            {
                braced(&mut out, text, node, "block");
            }
        }
        "comment" => comment(&mut out, &mut comments, text, node),
        "preproc_if" | "preproc_ifdef" => preproc(&mut out, text, node),
        "preproc_include" => includes.push(span(node)),
        kind => {
            if let Some((_, fold)) = BODIES.iter().find(|(k, _)| *k == kind)
                && let Some(body) = node.child_by_field_name("body")
            {
                braced(&mut out, text, body, fold);
            }
        }
    });
    runs(&mut out, text, &comments, "comment");
    runs(&mut out, text, &includes, "include");
    finish(out)
}

fn comment(out: &mut Vec<FoldRange>, lines: &mut Vec<(usize, usize)>, text: &str, node: Node<'_>) {
    let (start, end) = span(node);
    let body = &text[start..end.min(text.len())];
    if body.starts_with("//") {
        lines.push((start, end));
    } else if body.contains('\n') {
        closed(out, text, start, end, "comment");
    }
}

fn preproc(out: &mut Vec<FoldRange>, text: &str, node: Node<'_>) {
    let mut starts = Vec::new();
    directives(node, &mut starts);
    let close = last_content(text, node.start_byte(), node.end_byte());
    between(out, text, &starts, close, "preproc");
}

fn directives(node: Node<'_>, starts: &mut Vec<usize>) {
    starts.push(node.start_byte());
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        if child.kind().starts_with("preproc_el") {
            directives(child, starts);
        }
    }
}
