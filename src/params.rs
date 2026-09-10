#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Params {
    pub open: usize,
    pub close: usize,
    pub ranges: Vec<(usize, usize)>,
}

const SELF_PARAMS: &[&str] = &["self", "&self", "&mut self", "mut self"];

pub fn parse(signature: &str, name: &str) -> Option<Params> {
    let open = open_paren(signature, name)?;
    let bytes = signature.as_bytes();
    let mut depth = 0i32;
    let mut angle = 0i32;
    let mut ranges = Vec::new();
    let mut start = open + 1;
    let mut i = open;
    while i < bytes.len() {
        let c = bytes[i] as char;
        match c {
            '(' | '[' | '{' => depth += 1,
            ')' | ']' | '}' => {
                depth -= 1;
                if depth == 0 {
                    push_range(signature, start, i, &mut ranges);
                    return Some(Params {
                        open,
                        close: i,
                        ranges,
                    });
                }
            }
            '-' if bytes.get(i + 1) == Some(&b'>') => i += 1,
            '<' => angle += 1,
            '>' => angle -= 1,
            ',' if depth == 1 && angle <= 0 => {
                push_range(signature, start, i, &mut ranges);
                start = i + 1;
            }
            _ => {}
        }
        i += 1;
    }
    None
}

pub fn names(signature: &str, params: &Params) -> Vec<String> {
    params
        .ranges
        .iter()
        .enumerate()
        .map(|(i, (s, e))| name_of(&signature[*s..*e], i + 1))
        .collect()
}

fn open_paren(signature: &str, name: &str) -> Option<usize> {
    let mut search = 0;
    while let Some(pos) = signature[search..].find(name) {
        let abs = search + pos;
        let rest = signature[abs + name.len()..].trim_start_matches('!');
        let after = rest.trim_start();
        if after.starts_with('(') || after.starts_with('<') {
            let paren = signature[abs..].find('(')?;
            return Some(abs + paren);
        }
        search = abs + name.len().max(1);
    }
    signature.find('(')
}

fn push_range(signature: &str, start: usize, end: usize, out: &mut Vec<(usize, usize)>) {
    let raw = &signature[start..end];
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "void" || SELF_PARAMS.contains(&trimmed) {
        return;
    }
    if trimmed.starts_with("self:") || trimmed.starts_with("mut self:") {
        return;
    }
    let lead = raw.len() - raw.trim_start().len();
    out.push((start + lead, start + lead + trimmed.len()));
}

fn name_of(param: &str, index: usize) -> String {
    if let Some((pat, _)) = param.split_once(':') {
        let pat = pat.trim().trim_start_matches("mut ").trim();
        if pat.chars().all(|c| c.is_alphanumeric() || c == '_') && !pat.is_empty() {
            return pat.to_string();
        }
        return format!("arg{index}");
    }
    let cleaned: String = param
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || c == '_' {
                c
            } else {
                ' '
            }
        })
        .collect();
    let words: Vec<&str> = cleaned.split_whitespace().collect();
    let last_is_name = words.len() >= 2 && !param.trim_end().ends_with(['*', '&']);
    match words.last() {
        Some(w) if last_is_name && !w.chars().all(|c| c.is_ascii_digit()) => w.to_string(),
        _ => format!("arg{index}"),
    }
}
