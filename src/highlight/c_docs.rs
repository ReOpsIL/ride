use tree_sitter::Node;

use crate::text::{cap, collapse_ws};

const SIGNATURE_MAX: usize = 160;
const DOC_MAX: usize = 400;
const ATTACHED: &[&str] = &["declaration", "field_declaration", "type_definition"];
const BRIEF: &[&str] = &["@brief", "\\brief"];

pub fn signature(node: Node<'_>, text: &str) -> String {
    let slice = text
        .get(node.start_byte()..signature_end(node))
        .unwrap_or("");
    let head = slice.trim().trim_end_matches([';', '=', ':']).trim();
    cap(collapse_ws(head), SIGNATURE_MAX)
}

fn signature_end(node: Node<'_>) -> usize {
    let mut end = node.end_byte();
    let mut clip = |at: Option<usize>| {
        if let Some(at) = at {
            end = end.min(at);
        }
    };
    clip(node.child_by_field_name("body").map(|b| b.start_byte()));
    clip(
        node.child_by_field_name("default_value")
            .map(|v| v.start_byte()),
    );
    clip(node.child_by_field_name("value").map(|v| v.start_byte()));
    let mut cursor = node.walk();
    clip(
        node.named_children(&mut cursor)
            .find(|c| c.kind() == "field_initializer_list")
            .map(|c| c.start_byte()),
    );
    let mut cursor = node.walk();
    clip(
        node.children_by_field_name("declarator", &mut cursor)
            .find(|d| d.kind() == "init_declarator")
            .and_then(|d| d.child_by_field_name("declarator"))
            .map(|d| d.end_byte()),
    );
    end
}

pub fn doc(node: Node<'_>, text: &str) -> String {
    let mut next = anchor(node);
    let mut blocks = Vec::new();
    while let Some(prev) = next.prev_named_sibling() {
        if prev.kind() != "comment" || !adjacent(prev, next, text) {
            break;
        }
        let raw = prev.utf8_text(text.as_bytes()).unwrap_or_default();
        let block = raw.starts_with("/*");
        blocks.push(strip(raw));
        next = prev;
        if block {
            break;
        }
    }
    blocks.reverse();
    cap(blocks.join("\n").trim().to_string(), DOC_MAX)
}

fn anchor(node: Node<'_>) -> Node<'_> {
    let mut anchor = node;
    while let Some(parent) = anchor.parent() {
        let preceded = anchor
            .prev_named_sibling()
            .is_some_and(|p| p.kind() == "comment");
        let attached = parent.kind() == "template_declaration"
            || (ATTACHED.contains(&parent.kind()) && anchor.prev_named_sibling().is_none());
        if preceded || !attached {
            break;
        }
        anchor = parent;
    }
    anchor
}

fn adjacent(comment: Node<'_>, next: Node<'_>, text: &str) -> bool {
    let Some(gap) = text.get(comment.end_byte()..next.start_byte()) else {
        return false;
    };
    let line_start = text[..comment.start_byte()]
        .rfind('\n')
        .map_or(0, |i| i + 1);
    gap.chars().all(char::is_whitespace)
        && gap.matches('\n').count() <= 1
        && text[line_start..comment.start_byte()]
            .chars()
            .all(char::is_whitespace)
}

fn strip(raw: &str) -> String {
    let lines: Vec<String> = if let Some(rest) = raw.strip_prefix("//") {
        vec![line(rest.trim_start_matches(['/', '!', '<']))]
    } else {
        let inner = raw
            .trim_start_matches("/*")
            .trim_start_matches(['*', '!'])
            .trim_end_matches("*/");
        inner
            .lines()
            .map(|l| line(l.trim_start().strip_prefix('*').unwrap_or(l)))
            .collect()
    };
    let text = lines.join("\n");
    text.trim_matches('\n').to_string()
}

fn line(l: &str) -> String {
    let t = l.trim();
    BRIEF
        .iter()
        .find_map(|b| t.strip_prefix(b))
        .map_or(t, str::trim)
        .to_string()
}
