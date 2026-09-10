pub const MIN_HUMP: usize = 2;

pub fn hump(name: &str) -> String {
    let mut out = String::new();
    let mut prev: Option<char> = None;
    for c in name.chars() {
        if c.is_alphabetic() && starts_word(prev, c) {
            out.extend(c.to_lowercase());
        }
        prev = Some(c);
    }
    out
}

fn starts_word(prev: Option<char>, c: char) -> bool {
    match prev {
        None => true,
        Some(p) => p == '_' || p.is_ascii_digit() || (p.is_lowercase() && c.is_uppercase()),
    }
}
