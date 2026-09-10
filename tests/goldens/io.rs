#[derive(Clone, Debug)]
pub struct Case {
    pub path: String,
    pub after: String,
    pub typed: String,
}

fn escape(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('\n', "\\n")
        .replace('\t', "\\t")
}

fn unescape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }
        match chars.next() {
            Some('n') => out.push('\n'),
            Some('t') => out.push('\t'),
            Some('\\') => out.push('\\'),
            Some(other) => {
                out.push('\\');
                out.push(other);
            }
            None => out.push('\\'),
        }
    }
    out
}

fn parse_header(line: &str) -> Case {
    let mut parts = line.splitn(3, '\t');
    Case {
        path: parts.next().expect("path").to_string(),
        after: unescape(parts.next().expect("after")),
        typed: unescape(parts.next().expect("typed")),
    }
}

pub fn parse(text: &str) -> Vec<(Case, Vec<String>)> {
    let mut out = Vec::new();
    let mut cur: Option<(Case, Vec<String>)> = None;
    for line in text.lines() {
        if line.is_empty() {
            continue;
        }
        if line.contains('\t') {
            if let Some(block) = cur.take() {
                out.push(block);
            }
            cur = Some((parse_header(line), Vec::new()));
            continue;
        }
        match &mut cur {
            Some((_, names)) => names.push(line.to_string()),
            None => panic!("name before header: {line}"),
        }
    }
    if let Some(block) = cur {
        out.push(block);
    }
    out
}

pub fn render(blocks: &[(Case, Vec<String>)]) -> String {
    let mut out = String::new();
    for (i, (case, names)) in blocks.iter().enumerate() {
        if i > 0 {
            out.push('\n');
        }
        out.push_str(&case.path);
        out.push('\t');
        out.push_str(&escape(&case.after));
        out.push('\t');
        out.push_str(&escape(&case.typed));
        out.push('\n');
        for name in names {
            out.push_str(name);
            out.push('\n');
        }
    }
    out
}

pub fn place(src: &str, after: &str, typed: &str) -> (String, usize) {
    let start = src
        .find(after)
        .unwrap_or_else(|| panic!("anchor not found: {after:?}"));
    let mut text = src.to_string();
    let mut at = start + after.len();
    text.insert_str(at, typed);
    at += typed.len();
    (text, at)
}

pub fn diff(expected: &str, actual: &str) -> String {
    let exp: Vec<&str> = expected.lines().collect();
    let act: Vec<&str> = actual.lines().collect();
    let mut out = String::from("--- expected\n+++ actual\n");
    let n = exp.len().max(act.len());
    for i in 0..n {
        match (exp.get(i), act.get(i)) {
            (Some(a), Some(b)) if a == b => {}
            (Some(a), Some(b)) => out.push_str(&format!("-{a}\n+{b}\n")),
            (Some(a), None) => out.push_str(&format!("-{a}\n")),
            (None, Some(b)) => out.push_str(&format!("+{b}\n")),
            _ => {}
        }
    }
    out
}
