use tree_sitter::Node;

use super::complete_kind::{bare_expr, header_end, header_without_body, missing_semi};
use crate::ffi::TextEdit;

pub fn edit(root: Node<'_>, text: &str, byte: u32) -> TextEdit {
    let at = (byte as usize).min(root.end_byte());
    let before = at.saturating_sub(1);
    let leaf = root
        .descendant_for_byte_range(before, at)
        .or_else(|| root.descendant_for_byte_range(at, at))
        .unwrap_or(root);
    if let Some(node) = climb(leaf, header_without_body) {
        return braces(text, header_end(node));
    }
    if let Some(pos) = climb_map(leaf, missing_semi) {
        return insert(pos, ";", pos + 1);
    }
    if let Some(node) = climb(leaf, bare_expr) {
        let pos = node.end_byte() as u32;
        return insert(pos, ";", pos + 1);
    }
    new_line(text, byte)
}

pub fn new_line(text: &str, byte: u32) -> TextEdit {
    let at = (byte as usize).min(text.len());
    let start = text[..at].rfind('\n').map_or(0, |i| i + 1);
    let end = text[at..].find('\n').map_or(text.len(), |i| at + i);
    let indent = leading(&text[start..end]);
    let inserted = format!("\n{indent}");
    let pos = end as u32;
    insert(pos, &inserted, pos + inserted.len() as u32)
}

fn climb<'a>(mut node: Node<'a>, pred: impl Fn(Node<'a>) -> bool) -> Option<Node<'a>> {
    loop {
        if pred(node) {
            return Some(node);
        }
        node = node.parent()?;
    }
}

fn climb_map<'a, T>(mut node: Node<'a>, f: impl Fn(Node<'a>) -> Option<T>) -> Option<T> {
    loop {
        if let Some(found) = f(node) {
            return Some(found);
        }
        node = node.parent()?;
    }
}

fn braces(text: &str, at: u32) -> TextEdit {
    let indent = line_indent(text, at);
    let inner = format!("{indent}{}", unit(&indent));
    let inserted = format!(" {{\n{inner}\n{indent}}}");
    insert(at, &inserted, at + 3 + inner.len() as u32)
}

fn insert(at: u32, text: &str, caret: u32) -> TextEdit {
    TextEdit {
        start_byte: at,
        end_byte: at,
        text: text.to_string(),
        caret_byte: caret,
    }
}

fn line_indent(text: &str, byte: u32) -> String {
    let at = (byte as usize).min(text.len());
    let start = text[..at].rfind('\n').map_or(0, |i| i + 1);
    leading(&text[start..])
}

fn leading(line: &str) -> String {
    line.chars()
        .take_while(|c| *c == ' ' || *c == '\t')
        .collect()
}

fn unit(indent: &str) -> &'static str {
    if indent.contains('\t') { "\t" } else { "    " }
}
