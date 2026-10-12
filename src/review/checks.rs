use super::model::Change;

pub fn lights(
    change: Change,
    path: &str,
    signature: &str,
    is_test: bool,
    old_scan: &str,
    new_scan: &str,
) -> Vec<String> {
    let mut out = Vec::new();
    if change == Change::Signature && is_public(path, signature, new_scan) {
        out.push("public signature".to_string());
    }
    if change == Change::Added {
        out.push("added".to_string());
    }
    if change == Change::Removed {
        out.push("removed".to_string());
    }
    if risk(old_scan) != risk(new_scan) {
        out.push("unsafe".to_string());
    }
    if is_test && weakened(old_scan, new_scan) {
        out.push("test weakened".to_string());
    }
    if panics(new_scan) > panics(old_scan) {
        out.push("new panic".to_string());
    }
    out
}

fn is_public(path: &str, signature: &str, scan: &str) -> bool {
    header(path) || has_pub(signature) || has_pub(scan)
}

fn header(path: &str) -> bool {
    matches!(
        path.rsplit('.').next(),
        Some("h" | "hpp" | "hh" | "hxx" | "h++")
    )
}

fn has_pub(text: &str) -> bool {
    words(text, "pub") > 0
}

fn weakened(old: &str, new: &str) -> bool {
    asserts(new) < asserts(old)
        || (marked(new, "#[ignore") && !marked(old, "#[ignore"))
        || (marked(new, "should_panic") && !marked(old, "should_panic"))
}

fn marked(text: &str, needle: &str) -> bool {
    text.contains(needle)
}

fn asserts(text: &str) -> u32 {
    [
        "debug_assert_eq!",
        "debug_assert_ne!",
        "debug_assert!",
        "assert_eq!",
        "assert_ne!",
        "assert!",
    ]
    .into_iter()
    .map(|macro_name| count(text, macro_name))
    .sum()
}

fn panics(text: &str) -> u32 {
    count(text, "unwrap(")
        + count(text, "expect(")
        + count(text, "panic!")
        + count(text, "unreachable!")
}

fn risk(text: &str) -> [u32; 5] {
    [
        words(text, "unsafe"),
        words(text, "extern"),
        words(text, "transmute"),
        count(text, "*const") + count(text, "* const"),
        count(text, "*mut") + count(text, "* mut"),
    ]
}

fn words(text: &str, word: &str) -> u32 {
    let bytes = text.as_bytes();
    let needle = word.as_bytes();
    let mut count = 0;
    let mut index = 0;
    while index + needle.len() <= bytes.len() {
        if &bytes[index..index + needle.len()] == needle && edged(bytes, index, needle.len()) {
            count += 1;
            index += needle.len();
        } else {
            index += 1;
        }
    }
    count
}

fn edged(bytes: &[u8], index: usize, len: usize) -> bool {
    let before = index == 0 || !is_word(bytes[index - 1]);
    let after = index + len >= bytes.len() || !is_word(bytes[index + len]);
    before && after
}

fn is_word(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || byte == b'_'
}

fn count(text: &str, needle: &str) -> u32 {
    if needle.is_empty() {
        return 0;
    }
    let mut found = 0;
    let mut rest = text;
    while let Some(index) = rest.find(needle) {
        found += 1;
        rest = &rest[index + needle.len()..];
    }
    found
}
