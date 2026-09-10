const STDERR_TAIL: usize = 2000;

pub fn stderr_tail(text: &str) -> String {
    let start = text.len().saturating_sub(STDERR_TAIL);
    let mut idx = start;
    while !text.is_char_boundary(idx) {
        idx += 1;
    }
    text[idx..].to_string()
}
