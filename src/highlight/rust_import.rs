use crate::ffi::TextEdit;

pub fn edit(text: &str, import_path: &str) -> Option<TextEdit> {
    let line = format!("use {import_path};");
    if text.lines().any(|l| l.trim() == line) {
        return None;
    }
    let uses = use_lines(text);
    if let Some((_, last_end)) = uses.last() {
        let pos = sorted_position(text, &uses, &line).unwrap_or(*last_end);
        return Some(TextEdit {
            start_byte: pos as u32,
            end_byte: pos as u32,
            text: format!("{line}\n"),
        });
    }
    let pos = after_prelude(text);
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
    })
}

fn use_lines(text: &str) -> Vec<(usize, usize)> {
    let mut out = Vec::new();
    let mut offset = 0;
    let mut open: Option<usize> = None;
    let mut depth = 0i32;
    for line in text.split_inclusive('\n') {
        let trimmed = line.trim_start();
        let starts = open.is_none()
            && (trimmed.starts_with("use ")
                || trimmed.starts_with("pub use ")
                || trimmed.starts_with("pub(crate) use "))
            && line.len() - trimmed.len() == 0;
        if starts {
            open = Some(offset);
            depth = 0;
        }
        if let Some(start) = open {
            depth += line.matches('{').count() as i32 - line.matches('}').count() as i32;
            if depth <= 0 && line.contains(';') {
                out.push((start, offset + line.len()));
                open = None;
            }
        }
        offset += line.len();
    }
    out
}

fn sorted_position(text: &str, uses: &[(usize, usize)], line: &str) -> Option<usize> {
    let mut block: Vec<(usize, usize)> = Vec::new();
    for range in uses.iter().rev() {
        if let Some((start, _)) = block.last()
            && !text[range.1..*start].trim().is_empty()
        {
            break;
        }
        block.push(*range);
    }
    block.reverse();
    block
        .iter()
        .find(|(s, e)| text[*s..*e].trim_end() > line)
        .map(|(s, _)| *s)
        .or_else(|| block.last().map(|(_, e)| *e))
}

fn after_prelude(text: &str) -> usize {
    let mut offset = 0;
    let mut in_attr = false;
    for line in text.split_inclusive('\n') {
        let t = line.trim();
        let prelude = in_attr || t.starts_with("//!") || t.starts_with("#![") || t.is_empty();
        if !prelude {
            return offset;
        }
        if t.starts_with("#![") {
            in_attr = !t.ends_with(']');
        } else if in_attr && t.ends_with(']') {
            in_attr = false;
        }
        offset += line.len();
    }
    offset
}
