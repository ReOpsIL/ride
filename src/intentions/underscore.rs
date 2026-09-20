use crate::ffi::TextEdit;
use crate::highlight::BufferSession;

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
