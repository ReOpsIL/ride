use tree_sitter::{Node, Tree};

use super::{Context, ancestors, node_at};
use crate::highlight::site::word_start;

pub fn toml(tree: Option<&Tree>, text: &str, at: usize) -> Context {
    let start = word_start(text, at, &['-']);
    let line = line_head(text, at);
    if line.starts_with('[') {
        return Context::Table;
    }
    node_at(tree, start, at)
        .and_then(from_tree)
        .unwrap_or_else(|| fallback(line))
}

fn from_tree(node: Node<'_>) -> Option<Context> {
    ancestors(node).find_map(|n| match n.kind() {
        "pair" | "inline_table" | "table" | "table_array_element" => Some(Context::Key),
        _ => None,
    })
}

fn fallback(line: &str) -> Context {
    if line.is_empty() {
        Context::Table
    } else {
        Context::Key
    }
}

fn line_head(text: &str, at: usize) -> &str {
    let head = &text[..at];
    let line_start = head.rfind('\n').map(|i| i + 1).unwrap_or(0);
    head[line_start..].trim_start()
}
