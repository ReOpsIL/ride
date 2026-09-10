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
