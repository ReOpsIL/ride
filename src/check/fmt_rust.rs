use crate::error::EngineError;
use crate::ffi::OutlineItem;
use crate::highlight::BufferSession;

use super::fmt_run::run;

pub fn format_source(text: &str, edition: Option<&str>) -> Result<String, EngineError> {
    let edition = edition.unwrap_or("2024");
    run("rustfmt", ["--emit", "stdout", "--edition", edition], text)
}

pub fn format_range(
    text: &str,
    edition: Option<&str>,
    start_byte: u32,
    end_byte: u32,
) -> Result<String, EngineError> {
    let Some((start, end)) = item_span(text, start_byte, end_byte) else {
        return format_source(text, edition);
    };
    splice(text, edition, start, end)
}

fn item_span(text: &str, start_byte: u32, end_byte: u32) -> Option<(usize, usize)> {
    let (session, _) = BufferSession::open(text.to_string(), None).ok()?;
    enclosing(session.outline(), start_byte, end_byte.max(start_byte))
}

fn enclosing(outline: &[OutlineItem], start: u32, end: u32) -> Option<(usize, usize)> {
    outline
        .iter()
        .filter(|item| item.start_byte <= start && end <= item.end_byte)
        .min_by_key(|item| item.end_byte.saturating_sub(item.start_byte))
        .map(|item| (item.start_byte as usize, item.end_byte as usize))
}

fn splice(
    text: &str,
    edition: Option<&str>,
    start: usize,
    end: usize,
) -> Result<String, EngineError> {
    let start = floor_boundary(text, start.min(text.len()));
    let end = floor_boundary(text, end.min(text.len())).max(start);
    let snippet = &text[start..end];
    let indent = leading_indent(text, start);
    let formatted = format_source(snippet, edition)?;
    let formatted = strip_added_newline(formatted, snippet.ends_with('\n'));
    let formatted = indent_body(&formatted, indent);
    let mut out = String::with_capacity(text.len() + formatted.len());
    out.push_str(&text[..start]);
    out.push_str(&formatted);
    out.push_str(&text[end..]);
    Ok(out)
}

fn strip_added_newline(formatted: String, snippet_had_newline: bool) -> String {
    if snippet_had_newline {
        return formatted;
    }
    match formatted.strip_suffix('\n') {
        Some(trimmed) => trimmed.to_string(),
        None => formatted,
    }
}

fn leading_indent(text: &str, start: usize) -> &str {
    let line_start = text[..start].rfind('\n').map(|i| i + 1).unwrap_or(0);
    let prefix = &text[line_start..start];
    if prefix.bytes().all(|b| b == b' ' || b == b'\t') {
        prefix
    } else {
        ""
    }
}

fn indent_body(formatted: &str, indent: &str) -> String {
    if indent.is_empty() {
        return formatted.to_string();
    }
    let mut out = String::with_capacity(formatted.len() + indent.len() * 8);
    for (i, line) in formatted.split('\n').enumerate() {
        if i > 0 {
            out.push('\n');
            if !line.is_empty() {
                out.push_str(indent);
            }
        }
        out.push_str(line);
    }
    out
}

fn floor_boundary(text: &str, mut byte: usize) -> usize {
    while byte > 0 && !text.is_char_boundary(byte) {
        byte -= 1;
    }
    byte
}
