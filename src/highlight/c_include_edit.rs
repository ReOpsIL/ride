use std::path::{Path, PathBuf};

use crate::ffi::TextEdit;

pub fn name(header: &Path, dirs: &[PathBuf]) -> Option<String> {
    let relative = dirs
        .iter()
        .filter_map(|dir| header.strip_prefix(dir).ok())
        .min_by_key(|rel| rel.components().count())
        .map(Path::to_path_buf)
        .or_else(|| header.file_name().map(PathBuf::from))?;
    let text = relative.to_str()?.to_string();
    (!text.is_empty()).then_some(text)
}

pub fn edit(text: &str, name: &str, quoted: bool) -> Option<TextEdit> {
    let line = if quoted {
        format!("#include \"{name}\"")
    } else {
        format!("#include <{name}>")
    };
    if text.lines().any(|l| l.trim() == line) {
        return None;
    }
    let pos = insert_at(text);
    let follows_blank = text[pos..].starts_with('\n') || text[pos..].is_empty();
    let insert = if follows_blank {
        format!("{line}\n")
    } else {
        format!("{line}\n\n")
    };
    Some(TextEdit {
        start_byte: pos as u32,
        end_byte: pos as u32,
        text: insert,
        caret_byte: pos as u32,
    })
}

fn insert_at(text: &str) -> usize {
    let mut offset = 0;
    let mut last_include = None;
    let mut prelude = 0;
    let mut in_prelude = true;
    for raw in text.split_inclusive('\n') {
        let trimmed = raw.trim();
        if trimmed.starts_with("#include") || trimmed.starts_with("#import") {
            last_include = Some(offset + raw.len());
            in_prelude = false;
        } else if in_prelude && is_prelude(trimmed) {
            prelude = offset + raw.len();
        } else {
            in_prelude = false;
        }
        offset += raw.len();
    }
    last_include.unwrap_or(prelude)
}

fn is_prelude(line: &str) -> bool {
    line.is_empty()
        || line.starts_with("//")
        || line.starts_with("/*")
        || line.starts_with('*')
        || line.starts_with("#pragma")
        || line.starts_with("#ifndef")
        || line.starts_with("#define")
}
