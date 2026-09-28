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

pub fn byte_at(text: &str, line: usize, character: usize, encoding: Encoding) -> usize {
    let start = text
        .split_inclusive('\n')
        .take(line)
        .map(str::len)
        .sum::<usize>()
        .min(text.len());
    let rest = &text[start..];
    let line_text = rest.split('\n').next().unwrap_or_default();
    let offset = match encoding {
        Encoding::Utf8 => character.min(line_text.len()),
        Encoding::Utf16 => utf16_offset(line_text, character),
    };
    let mut byte = start + offset;
    while !text.is_char_boundary(byte) {
        byte -= 1;
    }
    byte
}

fn utf16_offset(line: &str, units: usize) -> usize {
    let mut seen = 0;
    for (byte, ch) in line.char_indices() {
        if seen >= units {
            return byte;
        }
        seen += ch.len_utf16();
    }
    line.len()
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
    fn a_position_maps_back_to_its_byte() {
        let text = "fn a() {}\nlet é = s.";
        for encoding in [Encoding::Utf8, Encoding::Utf16] {
            let spot = position(text, text.len(), encoding);
            let line = spot["line"].as_u64().expect("line") as usize;
            let character = spot["character"].as_u64().expect("character") as usize;
            assert_eq!(byte_at(text, line, character, encoding), text.len());
        }
    }

    #[test]
    fn an_offset_inside_a_character_snaps_back() {
        assert_eq!(
            position("é", 1, Encoding::Utf8),
            json!({"line": 0, "character": 0})
        );
    }
}
