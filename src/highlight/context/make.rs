use tree_sitter::Tree;

use super::Context;
use crate::highlight::site::word_start;

const ASSIGN: &[&str] = &["::=", ":=", "?=", "+=", "!=", "="];

pub fn make(_: Option<&Tree>, text: &str, at: usize) -> Context {
    let start = word_start(text, at, &['-']);
    let head = &text[..start];
    let line_start = head.rfind('\n').map(|i| i + 1).unwrap_or(0);
    let line = &head[line_start..];
    if unclosed_call(line) {
        return Context::Function;
    }
    if line.starts_with('\t') {
        return Context::Recipe;
    }
    if ASSIGN.iter().any(|op| line.contains(op)) || line.contains(':') {
        return Context::Value;
    }
    Context::Item
}

fn unclosed_call(line: &str) -> bool {
    let mut depth = 0usize;
    let mut chars = line.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '$' if matches!(chars.peek(), Some('(') | Some('{')) => {
                chars.next();
                depth += 1;
            }
            ')' | '}' => depth = depth.saturating_sub(1),
            _ => {}
        }
    }
    depth > 0
}
