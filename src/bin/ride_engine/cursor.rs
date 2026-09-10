use std::path::Path;

pub struct Cursor {
    pub byte: Option<usize>,
    pub find: Option<String>,
    pub typed: Option<String>,
}

pub struct Placed {
    pub text: String,
    pub at: usize,
}

pub fn place(file: &Path, cursor: &Cursor) -> Result<Placed, String> {
    let mut text =
        std::fs::read_to_string(file).map_err(|_| format!("cannot read {}", file.display()))?;
    let mut at = match (&cursor.byte, &cursor.find) {
        (Some(b), _) => *b,
        (None, Some(anchor)) => text
            .find(anchor.as_str())
            .map(|i| i + anchor.len())
            .ok_or_else(|| format!("anchor not found: {anchor}"))?,
        (None, None) => text.len(),
    };
    if let Some(typed) = &cursor.typed {
        text.insert_str(at, typed);
        at += typed.len();
    }
    Ok(Placed { text, at })
}
