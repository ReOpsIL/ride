#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CallSite {
    pub name: String,
    pub qualifier: Option<String>,
    pub active_parameter: u32,
    pub open_paren: usize,
}

const WINDOW: usize = 8000;
const NOT_CALLS: &[&str] = &["if", "while", "for", "switch", "match", "return", "sizeof"];

pub fn find(text: &str, at: usize) -> Option<CallSite> {
    let at = at.min(text.len());
    let start = text[..at]
        .char_indices()
        .rev()
        .nth(WINDOW)
        .map(|(i, _)| i)
        .unwrap_or(0);
    let start = text[..start].rfind('\n').map(|i| i + 1).unwrap_or(start);
    let (open, commas) = enclosing_paren(&text[start..at])?;
    let open = start + open;
    let head = text[..open].trim_end();
    let name_start = head
        .trim_end_matches(|c: char| c.is_alphanumeric() || c == '_' || c == '!')
        .len();
    let name = head[name_start..].trim_end_matches('!').to_string();
    if name.is_empty() || NOT_CALLS.contains(&name.as_str()) {
        return None;
    }
    let before = &head[..name_start];
    let qualifier = if let Some(q) = before.strip_suffix("::") {
        last_word(q)
    } else if let Some(q) = before
        .strip_suffix("->")
        .or_else(|| before.strip_suffix('.'))
    {
        last_word(q)
    } else {
        None
    };
    Some(CallSite {
        name,
        qualifier,
        active_parameter: commas,
        open_paren: open,
    })
}

fn last_word(s: &str) -> Option<String> {
    let trimmed = s.trim_end_matches(|c: char| c.is_alphanumeric() || c == '_');
    let word = &s[trimmed.len()..];
    (!word.is_empty()).then(|| word.to_string())
}

fn enclosing_paren(text: &str) -> Option<(usize, u32)> {
    let mut stack: Vec<(char, usize, u32)> = Vec::new();
    let mut chars = text.char_indices().peekable();
    let mut quote: Option<char> = None;
    let mut line_comment = false;
    let mut block_comment = false;
    while let Some((i, c)) = chars.next() {
        if line_comment {
            line_comment = c != '\n';
            continue;
        }
        if block_comment {
            if c == '*' && chars.peek().is_some_and(|(_, n)| *n == '/') {
                chars.next();
                block_comment = false;
            }
            continue;
        }
        if let Some(q) = quote {
            if c == '\\' {
                chars.next();
            } else if c == q {
                quote = None;
            }
            continue;
        }
        match c {
            '"' => quote = Some('"'),
            '\'' if is_char_literal(text, i) => quote = Some('\''),
            '/' if chars.peek().is_some_and(|(_, n)| *n == '/') => line_comment = true,
            '/' if chars.peek().is_some_and(|(_, n)| *n == '*') => block_comment = true,
            '(' | '[' | '{' => stack.push((c, i, 0)),
            ')' | ']' | '}' => {
                stack.pop();
            }
            ',' => {
                if let Some(top) = stack.last_mut() {
                    top.2 += 1;
                }
            }
            ';' => stack.retain(|(open, _, _)| *open != '('),
            _ => {}
        }
    }
    stack
        .iter()
        .rev()
        .find(|(open, _, _)| *open == '(')
        .map(|(_, i, commas)| (*i, *commas))
}

fn is_char_literal(text: &str, i: usize) -> bool {
    let rest = &text[i + 1..];
    let mut it = rest.chars();
    match it.next() {
        Some('\\') => rest[1..].find('\'').is_some_and(|p| p <= 8),
        Some(_) => it.next() == Some('\''),
        None => false,
    }
}
