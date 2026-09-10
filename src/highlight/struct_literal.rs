#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LiteralState {
    pub written: Vec<String>,
    pub colon_follows: bool,
}

pub fn literal_state(text: &str, replace_start: usize, at: usize) -> LiteralState {
    let head = &text[..replace_start.min(text.len())];
    let written = open_brace(head)
        .map(|open| written_names(&head[open + 1..]))
        .unwrap_or_default();
    let colon_follows = text
        .get(at.min(text.len())..)
        .is_some_and(|rest| rest.trim_start().starts_with(':'));
    LiteralState {
        written,
        colon_follows,
    }
}

fn open_brace(head: &str) -> Option<usize> {
    let mut depth = 0usize;
    for (i, c) in head.char_indices().rev() {
        match c {
            '}' | ')' | ']' => depth += 1,
            '{' if depth == 0 => return Some(i),
            '{' | '(' | '[' => depth = depth.saturating_sub(1),
            _ => {}
        }
    }
    None
}

fn written_names(body: &str) -> Vec<String> {
    let mut names = Vec::new();
    let mut depth = 0usize;
    let mut start = 0;
    for (i, c) in body.char_indices() {
        match c {
            '{' | '(' | '[' => depth += 1,
            '}' | ')' | ']' => depth = depth.saturating_sub(1),
            ',' if depth == 0 => {
                push_name(&mut names, &body[start..i]);
                start = i + 1;
            }
            _ => {}
        }
    }
    push_name(&mut names, &body[start..]);
    names
}

fn push_name(names: &mut Vec<String>, part: &str) {
    let name = part.trim().split(':').next().unwrap_or("").trim();
    if !name.is_empty() && name.chars().all(|c| c.is_alphanumeric() || c == '_') {
        names.push(name.to_string());
    }
}
