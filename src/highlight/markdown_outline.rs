use tree_sitter::Node;

use crate::ffi::{ItemKind, OutlineItem};

pub fn outline(root: Node<'_>, text: &str) -> Vec<OutlineItem> {
    let mut out = Vec::new();
    headings(root, text, &mut out);
    out
}

fn headings(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    if matches!(node.kind(), "atx_heading" | "setext_heading") {
        out.push(heading(node, text));
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        headings(child, text, out);
    }
}

fn heading(node: Node<'_>, text: &str) -> OutlineItem {
    let title = node
        .named_children(&mut node.walk())
        .find(|c| c.kind() == "inline" || c.kind() == "paragraph");
    let raw = title
        .and_then(|c| c.utf8_text(text.as_bytes()).ok())
        .unwrap_or("");
    let lead = raw.len() - raw.trim_start().len();
    let name_start_byte = title.map_or(node.start_byte(), |c| c.start_byte() + lead);
    OutlineItem {
        name: raw.trim().to_string(),
        kind: ItemKind::Heading,
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
        name_start_byte: name_start_byte as u32,
        signature: String::new(),
        doc: String::new(),
    }
}
