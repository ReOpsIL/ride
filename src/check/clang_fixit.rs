use std::path::{Path, PathBuf};

use crate::abspath::absolute;
use crate::ffi::{DiagnosticFix, TextEdit};

use super::offsets::LineOffsets;

const PREFIX: &str = "fix-it:\"";

pub struct Fixit {
    pub path: PathBuf,
    pub fix: DiagnosticFix,
}

pub fn parse(line: &str, base: &Path, offsets: &mut LineOffsets) -> Option<Fixit> {
    let rest = line.trim_start().strip_prefix(PREFIX)?;
    let (file, rest) = rest.split_once("\":{")?;
    let (range, rest) = rest.split_once("}:\"")?;
    let text = unescape(rest.strip_suffix('"')?);
    let (start, end) = span(range)?;
    let path = absolute(base, Path::new(file));
    let start_byte = offsets.byte_at(&path, start.0, start.1);
    let end_byte = offsets.byte_at(&path, end.0, end.1).max(start_byte);
    Some(Fixit {
        fix: DiagnosticFix {
            title: title(&text),
            edits: vec![TextEdit {
                start_byte,
                end_byte,
                text,
                caret_byte: end_byte,
            }],
        },
        path,
    })
}

fn title(text: &str) -> String {
    if text.is_empty() {
        "Remove".to_string()
    } else {
        format!("Apply fix: {text}")
    }
}

fn span(range: &str) -> Option<((u32, u32), (u32, u32))> {
    let (start, end) = range.split_once('-')?;
    Some((point(start)?, point(end)?))
}

fn point(text: &str) -> Option<(u32, u32)> {
    let (line, column) = text.split_once(':')?;
    Some((line.parse().ok()?, column.parse().ok()?))
}

fn unescape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    while let Some(c) = chars.next() {
        match (c, chars.peek()) {
            ('\\', Some('"' | '\\')) => out.extend(chars.next()),
            _ => out.push(c),
        }
    }
    out
}
