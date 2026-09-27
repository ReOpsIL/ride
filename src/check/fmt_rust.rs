use crate::error::EngineError;
use crate::ffi::OutlineItem;
use crate::highlight::BufferSession;
use crate::text::line_start;
use crate::toolchain::DEFAULT_EDITION;

use super::fmt_run::run;

pub struct RustSource<'a> {
    pub text: &'a str,
    pub file: Option<&'a str>,
    pub edition: Option<&'a str>,
}

pub fn format_source(source: &RustSource<'_>) -> Result<String, EngineError> {
    rustfmt(source.text, source)
}

pub fn format_range(
    source: &RustSource<'_>,
    start_byte: u32,
    end_byte: u32,
) -> Result<String, EngineError> {
    let Some((start, end)) = item_span(source.text, start_byte, end_byte) else {
        return format_source(source);
    };
    splice(source, start, end)
}

fn rustfmt(text: &str, source: &RustSource<'_>) -> Result<String, EngineError> {
    let edition = source.edition.unwrap_or(DEFAULT_EDITION);
    run(
        "rustfmt",
        ["--emit", "stdout", "--edition", edition],
        text,
        source.file,
    )
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

fn splice(source: &RustSource<'_>, start: usize, end: usize) -> Result<String, EngineError> {
    let text = source.text;
    let start = crate::text::floor_char_boundary(text, start.min(text.len()));
    let end = crate::text::floor_char_boundary(text, end.min(text.len())).max(start);
    let snippet = &text[start..end];
    let indent = leading_indent(text, start);
    let formatted = rustfmt(snippet, source)?;
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
    let line_start = line_start(text, start);
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
