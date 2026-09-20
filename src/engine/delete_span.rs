use tree_sitter::Node;

use crate::highlight::Lang;
use crate::text::line_start;

use super::doc_block;

pub fn deletion_range(lang: Lang, text: &str, start: u32, end: u32) -> (u32, u32) {
    let start = start as usize;
    let end = (end as usize).min(text.len());
    let start = expand_start(lang, text, start).unwrap_or_else(|| line_start(text, start));
    let end = include_trailing(text, end);
    (start as u32, end.max(start) as u32)
}

fn expand_start(lang: Lang, text: &str, start: usize) -> Option<usize> {
    let tree = doc_block::parse(lang, text)?;
    let mut node = item_node(tree.root_node(), start)?;
    let mut first = node;
    while let Some(prev) = node.prev_named_sibling() {
        if !is_prefix(prev) || !attached(prev, node, text) {
            break;
        }
        first = prev;
        node = prev;
    }
    Some(line_start(text, first.start_byte()))
}

fn item_node<'a>(root: Node<'a>, start: usize) -> Option<Node<'a>> {
    let last = root.end_byte().saturating_sub(1);
    let at = start.min(last);
    let mut node = root.descendant_for_byte_range(at, at)?;
    let mut best = None;
    loop {
        if node.start_byte() == start {
            best = Some(node);
        }
        match node.parent() {
            Some(parent) => node = parent,
            None => break,
        }
    }
    best
}

fn is_prefix(node: Node<'_>) -> bool {
    matches!(
        node.kind(),
        "line_comment" | "block_comment" | "comment" | "attribute_item" | "inner_attribute_item"
    )
}

fn attached(prev: Node<'_>, next: Node<'_>, text: &str) -> bool {
    let Some(gap) = text.get(prev.end_byte()..next.start_byte()) else {
        return false;
    };
    gap.chars().all(char::is_whitespace) && gap.matches('\n').count() <= 1
}

fn include_trailing(text: &str, end: usize) -> usize {
    let bytes = text.as_bytes();
    let mut i = end.min(bytes.len());
    while i < bytes.len() && !is_nl(bytes[i]) {
        if !bytes[i].is_ascii_whitespace() {
            return end;
        }
        i += 1;
    }
    i = eat_nl(bytes, i);
    let after_line = i;
    let mut j = i;
    while j < bytes.len() && !is_nl(bytes[j]) {
        if !bytes[j].is_ascii_whitespace() {
            return after_line;
        }
        j += 1;
    }
    if j == i && j == bytes.len() {
        return after_line;
    }
    eat_nl(bytes, j)
}

fn is_nl(b: u8) -> bool {
    b == b'\n' || b == b'\r'
}

fn eat_nl(bytes: &[u8], mut i: usize) -> usize {
    if i < bytes.len() && bytes[i] == b'\r' {
        i += 1;
    }
    if i < bytes.len() && bytes[i] == b'\n' {
        i += 1;
    }
    i
}
