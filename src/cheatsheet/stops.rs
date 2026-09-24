#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StopError {
    Unclosed,
    BraceInPlaceholder,
}

impl StopError {
    pub fn message(self) -> &'static str {
        match self {
            StopError::Unclosed => "has an unclosed tab stop",
            StopError::BraceInPlaceholder => "has an unbalanced brace inside a tab stop",
        }
    }
}

pub fn check(snippet: &str) -> Result<(), StopError> {
    let chars: Vec<char> = snippet.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        i = match chars[i] {
            '\\' => i + 2,
            '$' if chars.get(i + 1) == Some(&'{') => match braced(&chars, i + 2)? {
                Some(end) => end,
                None => i + 1,
            },
            _ => i + 1,
        };
    }
    Ok(())
}

fn braced(chars: &[char], start: usize) -> Result<Option<usize>, StopError> {
    let after_digits = digits(chars, start);
    if after_digits == start {
        return Ok(None);
    }
    match chars.get(after_digits) {
        Some('}') => Ok(Some(after_digits + 1)),
        Some(':') => placeholder(chars, after_digits + 1).map(Some),
        _ => Err(StopError::Unclosed),
    }
}

fn digits(chars: &[char], start: usize) -> usize {
    let mut i = start;
    while chars.get(i).is_some_and(char::is_ascii_digit) {
        i += 1;
    }
    i
}

fn placeholder(chars: &[char], start: usize) -> Result<usize, StopError> {
    let mut opens = 0i32;
    let mut i = start;
    while i < chars.len() {
        match chars[i] {
            '\\' => {
                opens += brace_delta(chars.get(i + 1).copied());
                i += 2;
            }
            '}' if opens == 0 => return Ok(i + 1),
            '}' => return Err(StopError::BraceInPlaceholder),
            '{' => {
                opens += 1;
                i += 1;
            }
            _ => i += 1,
        }
    }
    Err(StopError::Unclosed)
}

fn brace_delta(c: Option<char>) -> i32 {
    match c {
        Some('{') => 1,
        Some('}') => -1,
        _ => 0,
    }
}
