pub fn first_sentence(doc: &str) -> String {
    let t = doc.trim();
    if t.is_empty() {
        return String::new();
    }
    t.split_once('.')
        .map(|(a, _)| a.trim().to_string())
        .unwrap_or_else(|| t.to_string())
}

pub fn collapse_ws(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub fn first_line(s: &str) -> String {
    s.lines().next().unwrap_or("").trim().to_string()
}

pub fn cap(mut s: String, max_chars: usize) -> String {
    if let Some((cut, _)) = s.char_indices().nth(max_chars) {
        s.truncate(cut);
        s.push('…');
    }
    s
}

pub fn is_word(c: char) -> bool {
    c.is_alphanumeric() || c == '_'
}

pub fn line_start(text: &str, byte: usize) -> usize {
    let byte = byte.min(text.len());
    text[..byte].rfind('\n').map(|i| i + 1).unwrap_or(0)
}

pub fn line_end(text: &str, byte: usize) -> usize {
    let byte = byte.min(text.len());
    text[byte..]
        .find('\n')
        .map(|i| byte + i)
        .unwrap_or(text.len())
}

pub fn names_inline_arg(literal: &str, name: &str) -> bool {
    let mut rest = literal;
    while let Some(open) = rest.find('{') {
        let after = &rest[open + 1..];
        if let Some(escaped) = after.strip_prefix('{') {
            rest = escaped;
            continue;
        }
        let end = after.find(['}', ':']).unwrap_or(after.len());
        if after[..end].trim() == name {
            return true;
        }
        rest = after;
    }
    false
}

pub fn indent_at(text: &str, at: usize) -> String {
    let start = text
        .get(..at)
        .and_then(|head| head.rfind('\n').map(|i| i + 1))
        .unwrap_or(0);
    text.get(start..at)
        .unwrap_or_default()
        .chars()
        .take_while(|c| c.is_whitespace())
        .collect()
}

pub fn floor_char_boundary(text: &str, at: usize) -> usize {
    let mut at = at.min(text.len());
    while !text.is_char_boundary(at) {
        at -= 1;
    }
    at
}
