use tree_sitter::Node;

use super::item::node_text;

pub fn first_paragraph(docs: &str) -> String {
    let trimmed = docs.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    trimmed
        .split("\n\n")
        .next()
        .unwrap_or(trimmed)
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

pub fn preceding_docs(node: Node<'_>, source: &str) -> String {
    let mut chunks = Vec::new();
    let mut sib = node.prev_named_sibling();
    while let Some(s) = sib {
        match s.kind() {
            "line_comment" | "block_comment" => {
                if let Some(text) = comment_doc(s, source) {
                    chunks.push(text);
                } else {
                    break;
                }
            }
            "attribute_item" => {}
            _ => break,
        }
        sib = s.prev_named_sibling();
    }
    chunks.reverse();
    first_paragraph(&chunks.join("\n"))
}

pub fn inner_docs(root: Node<'_>, source: &str) -> String {
    let mut chunks = Vec::new();
    for i in 0..root.named_child_count() {
        let Some(child) = super::ts::child_at(root, i) else {
            continue;
        };
        match child.kind() {
            "line_comment" | "block_comment" => {
                if let Some(text) = inner_comment_doc(child, source) {
                    chunks.push(text);
                } else if comment_doc(child, source).is_none() {
                    break;
                }
            }
            "inner_attribute_item" => {}
            _ => break,
        }
    }
    first_paragraph(&chunks.join("\n"))
}

pub fn signature(node: Node<'_>, source: &str) -> String {
    let full = node_text(node, source);
    if let Some(body) = node.child_by_field_name("body") {
        let start = node.start_byte();
        let body_start = body.start_byte();
        if body_start > start
            && let Some(slice) = source.get(start..body_start)
        {
            return collapse_ws(slice.trim_end().trim_end_matches('{').trim_end());
        }
    }
    collapse_ws(full.trim_end_matches(';').trim())
}

pub fn source_chunk(node: Node<'_>, source: &str) -> String {
    let start = node.start_byte();
    let end = node.end_byte().min(source.len());
    let Some(slice) = source.get(start..end) else {
        return String::new();
    };
    let mut lines = slice.lines();
    let mut out = String::new();
    for _ in 0..40 {
        let Some(line) = lines.next() else {
            break;
        };
        if !out.is_empty() {
            out.push('\n');
        }
        out.push_str(line);
        if out.len() > 2048 {
            break;
        }
    }
    out
}

fn comment_doc(node: Node<'_>, source: &str) -> Option<String> {
    let text = node.utf8_text(source.as_bytes()).ok()?.trim();
    strip_outer(text)
}

fn inner_comment_doc(node: Node<'_>, source: &str) -> Option<String> {
    let text = node.utf8_text(source.as_bytes()).ok()?.trim();
    strip_inner(text)
}

fn strip_outer(text: &str) -> Option<String> {
    if let Some(rest) = text.strip_prefix("///") {
        return Some(rest.trim().to_string());
    }
    if let Some(rest) = text.strip_prefix("/**") {
        return Some(rest.trim().trim_end_matches("*/").trim().to_string());
    }
    None
}

fn strip_inner(text: &str) -> Option<String> {
    if let Some(rest) = text.strip_prefix("//!") {
        return Some(rest.trim().to_string());
    }
    if let Some(rest) = text.strip_prefix("/*!") {
        return Some(rest.trim().trim_end_matches("*/").trim().to_string());
    }
    None
}

fn collapse_ws(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}
