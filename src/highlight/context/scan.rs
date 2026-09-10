use super::Context;

const CONTROL: &[&str] = &["if", "while", "for", "switch", "catch"];

pub fn statement_or_expression(text: &str, start: usize) -> Context {
    let head = text[..start].trim_end();
    if head.is_empty()
        || head.ends_with([';', '{', '}'])
        || head.ends_with("else")
        || after_control_paren(head)
    {
        Context::Statement
    } else {
        Context::Expression
    }
}

fn after_control_paren(head: &str) -> bool {
    if !head.ends_with(')') {
        return false;
    }
    let bytes = head.as_bytes();
    let mut depth = 0usize;
    let mut open = None;
    for i in (0..bytes.len()).rev() {
        match bytes[i] {
            b')' => depth += 1,
            b'(' => {
                depth -= 1;
                if depth == 0 {
                    open = Some(i);
                    break;
                }
            }
            _ => {}
        }
    }
    let Some(open) = open else {
        return false;
    };
    let before = head[..open].trim_end();
    let word_start = before.trim_end_matches(|c: char| c.is_alphanumeric() || c == '_');
    CONTROL.contains(&&before[word_start.len()..])
}

pub fn brace_depth(text: &str) -> usize {
    let mut depth = 0usize;
    let mut chars = text.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '"' => skip_quoted(&mut chars, '"'),
            '\'' => {
                if chars
                    .peek()
                    .is_some_and(|n| *n != '\'' && !n.is_alphanumeric())
                {
                    skip_quoted(&mut chars, '\'');
                }
            }
            '/' => match chars.peek() {
                Some('/') => {
                    for n in chars.by_ref() {
                        if n == '\n' {
                            break;
                        }
                    }
                }
                Some('*') => {
                    chars.next();
                    let mut prev = ' ';
                    for n in chars.by_ref() {
                        if prev == '*' && n == '/' {
                            break;
                        }
                        prev = n;
                    }
                }
                _ => {}
            },
            '{' => depth += 1,
            '}' => depth = depth.saturating_sub(1),
            _ => {}
        }
    }
    depth
}

fn skip_quoted(chars: &mut std::iter::Peekable<std::str::Chars<'_>>, quote: char) {
    let mut escaped = false;
    for n in chars.by_ref() {
        if escaped {
            escaped = false;
        } else if n == '\\' {
            escaped = true;
        } else if n == quote || n == '\n' {
            break;
        }
    }
}
