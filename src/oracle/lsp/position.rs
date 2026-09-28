use serde_json::{Value, json};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Encoding {
    Utf8,
    Utf16,
}

impl Encoding {
    pub fn from_capabilities(capabilities: &Value) -> Self {
        match capabilities["positionEncoding"].as_str() {
            Some("utf-8") => Self::Utf8,
            _ => Self::Utf16,
        }
    }
}

pub fn position(text: &str, byte: usize, encoding: Encoding) -> Value {
    let mut byte = byte.min(text.len());
    while !text.is_char_boundary(byte) {
        byte -= 1;
    }
    let before = &text[..byte];
    let line_start = before.rfind('\n').map_or(0, |i| i + 1);
    let line = before.bytes().filter(|b| *b == b'\n').count();
    let character = match encoding {
        Encoding::Utf8 => byte - line_start,
        Encoding::Utf16 => before[line_start..].encode_utf16().count(),
    };
    json!({ "line": line, "character": character })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn columns_count_in_the_negotiated_unit() {
        let text = "fn a() {}\nlet é = s.";
        let end = text.len();
        assert_eq!(
            position(text, end, Encoding::Utf8),
            json!({"line": 1, "character": 11})
        );
        assert_eq!(
            position(text, end, Encoding::Utf16),
            json!({"line": 1, "character": 10})
        );
    }

    #[test]
    fn an_offset_inside_a_character_snaps_back() {
        assert_eq!(
            position("é", 1, Encoding::Utf8),
            json!({"line": 0, "character": 0})
        );
    }
}
