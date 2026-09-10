use tree_sitter::Tree;

use super::Position;

pub fn is_word(c: char) -> bool {
    c.is_alphanumeric() || c == '_'
}

pub fn word_start(text: &str, at: usize, extra: &[char]) -> usize {
    let head = &text[..at];
    let trimmed = head.trim_end_matches(|c: char| is_word(c) || extra.contains(&c));
    trimmed.len()
}

pub fn head_before(text: &str, start: usize) -> &str {
    text[..start].trim_end_matches([' ', '\t'])
}

pub fn inside(tree: Option<&Tree>, at: usize, kinds: &[&str]) -> bool {
    let Some(tree) = tree else {
        return false;
    };
    let probe = at.saturating_sub(1);
    let Some(mut node) = tree.root_node().descendant_for_byte_range(probe, probe) else {
        return false;
    };
    for _ in 0..4 {
        if kinds.contains(&node.kind()) {
            return true;
        }
        match node.parent() {
            Some(p) => node = p,
            None => return false,
        }
    }
    false
}

pub fn in_open_comment(text: &str, at: usize) -> bool {
    let head = &text[..at];
    let block_open = head.rfind("/*");
    let block_close = head.rfind("*/");
    if block_open.is_some_and(|o| block_close.is_none_or(|c| c < o)) {
        return true;
    }
    let line_start = head.rfind('\n').map(|i| i + 1).unwrap_or(0);
    head[line_start..].contains("//")
}

pub fn path_segments(head: &str) -> (Vec<String>, usize) {
    let mut segments = Vec::new();
    let mut end = head.len();
    loop {
        let Some(rest) = head[..end].strip_suffix("::") else {
            break;
        };
        let trimmed = rest.trim_end_matches(|c: char| is_word(c));
        let seg = &rest[trimmed.len()..];
        if seg.is_empty() {
            end = trimmed.len();
            break;
        }
        segments.push(seg.to_string());
        end = trimmed.len();
    }
    segments.reverse();
    (segments, end)
}

pub fn last_token(s: &str) -> &str {
    let s = s.trim_end();
    if s.is_empty() {
        return "";
    }
    let last = s.chars().next_back().unwrap_or(' ');
    if is_word(last) {
        let start = s.trim_end_matches(is_word).len();
        return &s[start..];
    }
    for op in ["->", "::", "==", "!=", "<=", ">=", "&&", "||", "=>", ".."] {
        if s.ends_with(op) {
            return &s[s.len() - op.len()..];
        }
    }
    &s[s.len() - last.len_utf8()..]
}

pub struct PositionWords {
    pub types: &'static [&'static str],
    pub values: &'static [&'static str],
    pub type_symbols: &'static [&'static str],
    pub value_symbols: &'static [&'static str],
    pub transparent: &'static [&'static str],
}

pub fn position(head: &str, words: &PositionWords) -> Position {
    let trimmed = head.trim_end();
    if trimmed.is_empty() || trimmed.ends_with('\n') {
        return Position::Value;
    }
    let tail = last_token(trimmed);
    if words.transparent.contains(&tail) {
        return position(&trimmed[..trimmed.len() - tail.len()], words);
    }
    if words.type_symbols.contains(&tail) || words.types.contains(&tail) {
        return Position::Type;
    }
    if words.value_symbols.contains(&tail) || words.values.contains(&tail) {
        return Position::Value;
    }
    Position::Unknown
}
