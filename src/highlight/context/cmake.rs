use tree_sitter::{Node, Tree};

use super::{Context, ancestors, node_at};
use crate::highlight::site::word_start;

pub fn cmake(tree: Option<&Tree>, text: &str, at: usize) -> Context {
    let start = word_start(text, at, &[]);
    node_at(tree, start, at)
        .and_then(from_tree)
        .unwrap_or_else(|| fallback(&text[..start]))
}

fn from_tree(node: Node<'_>) -> Option<Context> {
    ancestors(node).find_map(|n| match n.kind() {
        "argument_list" | "argument" | "quoted_argument" | "unquoted_argument"
        | "bracket_argument" => Some(Context::Argument),
        "body" => Some(Context::Statement),
        _ => None,
    })
}

fn fallback(head: &str) -> Context {
    if unclosed_paren(head) {
        Context::Argument
    } else {
        Context::Statement
    }
}

fn unclosed_paren(head: &str) -> bool {
    let mut depth = 0i32;
    let mut chars = head.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '"' => skip_quoted(&mut chars),
            '#' => skip_line(&mut chars),
            '(' => depth += 1,
            ')' => depth -= 1,
            _ => {}
        }
    }
    depth > 0
}

fn skip_quoted(chars: &mut std::iter::Peekable<std::str::Chars<'_>>) {
    let mut escaped = false;
    for n in chars.by_ref() {
        if escaped {
            escaped = false;
        } else if n == '\\' {
            escaped = true;
        } else if n == '"' || n == '\n' {
            break;
        }
    }
}

fn skip_line(chars: &mut std::iter::Peekable<std::str::Chars<'_>>) {
    for n in chars.by_ref() {
        if n == '\n' {
            break;
        }
    }
}
