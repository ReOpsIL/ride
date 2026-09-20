const LIMIT: u32 = 200;

pub fn placeholder(text: &str, base: &str) -> String {
    for n in 1..=LIMIT {
        let candidate = if n == 1 {
            base.to_string()
        } else {
            format!("{base}{n}")
        };
        if !contains_word(text, &candidate) {
            return candidate;
        }
    }
    format!("{base}{LIMIT}")
}

fn contains_word(text: &str, word: &str) -> bool {
    let bytes = text.as_bytes();
    let mut from = 0;
    while let Some(found) = text.get(from..).and_then(|rest| rest.find(word)) {
        let at = from + found;
        let before = at.checked_sub(1).map(|i| bytes[i]);
        let after = bytes.get(at + word.len()).copied();
        if !is_word_byte(before) && !is_word_byte(after) {
            return true;
        }
        from = at + word.len();
    }
    false
}

fn is_word_byte(byte: Option<u8>) -> bool {
    byte.is_some_and(|b| b.is_ascii_alphanumeric() || b == b'_')
}
