use tree_sitter::Node;

pub fn rust(node: Node<'_>, source: &str) -> String {
    let mut md = preceding(node, source);
    if matches!(node.kind(), "mod_item" | "source_file") {
        let inner = inner(node, source);
        if !inner.is_empty() {
            if !md.is_empty() {
                md.push_str("\n\n");
            }
            md.push_str(&inner);
        }
    }
    md
}

pub fn c(node: Node<'_>, source: &str) -> String {
    let mut next = c_anchor(node);
    let mut blocks = Vec::new();
    while let Some(prev) = next.prev_named_sibling() {
        if prev.kind() != "comment" || !adjacent(prev, next, source) {
            break;
        }
        let raw = prev.utf8_text(source.as_bytes()).unwrap_or("");
        let block = raw.trim_start().starts_with("/*");
        blocks.push(c_strip(raw));
        next = prev;
        if block {
            break;
        }
    }
    blocks.reverse();
    blocks.join("\n").trim().to_string()
}

fn preceding(node: Node<'_>, source: &str) -> String {
    let mut chunks = Vec::new();
    let mut sib = node.prev_named_sibling();
    while let Some(s) = sib {
        match s.kind() {
            "line_comment" | "block_comment" => match comment(s, source, false) {
                Some(text) => chunks.push(text),
                None => break,
            },
            "attribute_item" | "inner_attribute_item" => {}
            _ => break,
        }
        sib = s.prev_named_sibling();
    }
    chunks.reverse();
    chunks.join("\n")
}

fn inner(node: Node<'_>, source: &str) -> String {
    let root = node.child_by_field_name("body").unwrap_or(node);
    let mut chunks = Vec::new();
    let mut i = 0u32;
    while let Some(child) = root.named_child(i) {
        i += 1;
        match child.kind() {
            "line_comment" | "block_comment" => match comment(child, source, true) {
                Some(text) => chunks.push(text),
                None => {
                    if comment(child, source, false).is_none() {
                        break;
                    }
                }
            },
            "inner_attribute_item" => {}
            _ => break,
        }
    }
    chunks.join("\n")
}

fn comment(node: Node<'_>, source: &str, inner: bool) -> Option<String> {
    let text = node.utf8_text(source.as_bytes()).ok()?.trim();
    if inner {
        inner_text(text)
    } else {
        outer_text(text)
    }
}

fn outer_text(text: &str) -> Option<String> {
    if let Some(rest) = text.strip_prefix("///") {
        return Some(one_space(rest).to_string());
    }
    text.starts_with("/**").then(|| block_text(text))
}

fn inner_text(text: &str) -> Option<String> {
    if let Some(rest) = text.strip_prefix("//!") {
        return Some(one_space(rest).to_string());
    }
    text.starts_with("/*!").then(|| block_text(text))
}

fn one_space(s: &str) -> &str {
    s.strip_prefix(' ').unwrap_or(s)
}

fn block_text(text: &str) -> String {
    let inner = text
        .trim_start_matches("/**")
        .trim_start_matches("/*!")
        .trim_start_matches("/*")
        .trim_end_matches("*/");
    inner.lines().map(star_line).collect::<Vec<_>>().join("\n")
}

fn star_line(l: &str) -> &str {
    let t = l.trim_start();
    let t = t.strip_prefix('*').unwrap_or(t);
    t.strip_prefix(' ').unwrap_or(t).trim_end()
}

fn c_anchor(node: Node<'_>) -> Node<'_> {
    let mut anchor = node;
    while let Some(parent) = anchor.parent() {
        let preceded = anchor
            .prev_named_sibling()
            .is_some_and(|p| p.kind() == "comment");
        let attached = parent.kind() == "template_declaration"
            || (matches!(
                parent.kind(),
                "declaration" | "field_declaration" | "type_definition"
            ) && anchor.prev_named_sibling().is_none());
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
    let line_start = text
        .get(..comment.start_byte())
        .and_then(|s| s.rfind('\n'))
        .map_or(0, |i| i + 1);
    gap.chars().all(char::is_whitespace)
        && gap.matches('\n').count() <= 1
        && text
            .get(line_start..comment.start_byte())
            .is_some_and(|s| s.chars().all(char::is_whitespace))
}

fn c_strip(raw: &str) -> String {
    let raw = raw.trim();
    if let Some(rest) = raw.strip_prefix("//") {
        return rest.trim_start_matches(['/', '!', '<']).trim().to_string();
    }
    block_text(raw)
}
