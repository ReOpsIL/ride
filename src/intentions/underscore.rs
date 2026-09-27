use crate::ffi::TextEdit;
use crate::highlight::{BufferSession, Lang};
use crate::text::names_inline_arg;

use super::draft::Draft;

pub fn drafts(session: &BufferSession, caret: u32) -> Vec<Draft> {
    let occurrences = session.local_occurrences(caret);
    let [only] = occurrences.as_slice() else {
        return Vec::new();
    };
    let text = session.replica();
    let Some(name) = text.get(only.start_byte as usize..only.end_byte as usize) else {
        return Vec::new();
    };
    if name.is_empty() || name.starts_with('_') {
        return Vec::new();
    }
    if session.lang() == Lang::Rust && inline_format_use(text, only.end_byte as usize, name) {
        return Vec::new();
    }
    let replacement = format!("_{name}");
    let caret_byte = only.start_byte + replacement.len() as u32;
    vec![Draft::new(
        format!("Rename to _{name}"),
        vec![TextEdit {
            start_byte: only.start_byte,
            end_byte: only.end_byte,
            text: replacement,
            caret_byte,
        }],
    )]
}

fn inline_format_use(text: &str, from: usize, name: &str) -> bool {
    let bytes = text.as_bytes();
    let mut depth = 0usize;
    let mut i = from;
    while i < bytes.len() {
        match bytes[i] {
            b'"' => {
                let end = string_end(bytes, i);
                if text.get(i..end).is_some_and(|s| names_inline_arg(s, name)) {
                    return true;
                }
                i = end;
                continue;
            }
            b'{' => depth += 1,
            b'}' if depth == 0 => return false,
            b'}' => depth -= 1,
            _ => {}
        }
        i += 1;
    }
    false
}

fn string_end(bytes: &[u8], open: usize) -> usize {
    let mut i = open + 1;
    while i < bytes.len() {
        match bytes[i] {
            b'\\' => i += 2,
            b'"' => return i + 1,
            _ => i += 1,
        }
    }
    bytes.len()
}
