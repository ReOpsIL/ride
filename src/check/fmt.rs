use crate::error::EngineError;
use crate::highlight::Lang;
use crate::toolchain::find_tool;

use super::fmt_run::run;
use super::fmt_rust;
use super::make_fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Formatter {
    Rustfmt,
    ClangFormat,
    CmakeFormat,
    Taplo,
    Builtin,
}

impl Formatter {
    pub fn for_lang(lang: Lang) -> Option<Formatter> {
        match lang {
            Lang::Rust => Some(Formatter::Rustfmt),
            Lang::C | Lang::Cpp => Some(Formatter::ClangFormat),
            Lang::Cmake => Some(Formatter::CmakeFormat),
            Lang::Toml => Some(Formatter::Taplo),
            Lang::Make => Some(Formatter::Builtin),
            Lang::Markdown => None,
        }
    }

    pub fn tool(self) -> Option<&'static str> {
        match self {
            Formatter::Rustfmt => Some("rustfmt"),
            Formatter::ClangFormat => Some("clang-format"),
            Formatter::CmakeFormat => Some("cmake-format"),
            Formatter::Taplo => Some("taplo"),
            Formatter::Builtin => None,
        }
    }

    pub fn name(self) -> &'static str {
        self.tool().unwrap_or("builtin")
    }

    pub fn available(self) -> bool {
        match self.tool() {
            Some(name) => {
                find_tool(name).is_some()
                    || (self == Formatter::CmakeFormat && find_tool("gersemi").is_some())
            }
            None => true,
        }
    }
}

pub fn format_document(
    lang: Lang,
    text: &str,
    path: Option<&str>,
    edition: Option<&str>,
) -> Result<String, EngineError> {
    let Some(formatter) = Formatter::for_lang(lang) else {
        return Err(EngineError::Tool {
            message: "no formatter for this file type".into(),
        });
    };
    match formatter {
        Formatter::Rustfmt => format_source(text, edition),
        Formatter::ClangFormat => format_clang(text, path),
        Formatter::CmakeFormat => format_cmake(text),
        Formatter::Taplo => run("taplo", ["fmt", "-"], text),
        Formatter::Builtin => Ok(make_fmt::format(text)),
    }
}

pub fn format_range(
    lang: Lang,
    text: &str,
    path: Option<&str>,
    edition: Option<&str>,
    start_byte: u32,
    end_byte: u32,
) -> Result<String, EngineError> {
    match Formatter::for_lang(lang) {
        Some(Formatter::ClangFormat) => {
            let (from, to) = line_range(text, start_byte, end_byte);
            format_clang_lines(text, path, from, to)
        }
        Some(Formatter::Rustfmt) => fmt_rust::format_range(text, edition, start_byte, end_byte),
        _ => format_document(lang, text, path, edition),
    }
}

pub fn format_source(text: &str, edition: Option<&str>) -> Result<String, EngineError> {
    fmt_rust::format_source(text, edition)
}

pub fn format_clang(text: &str, assume_filename: Option<&str>) -> Result<String, EngineError> {
    clang(text, assume_filename, None)
}

fn format_clang_lines(
    text: &str,
    assume_filename: Option<&str>,
    from: u32,
    to: u32,
) -> Result<String, EngineError> {
    clang(text, assume_filename, Some((from, to)))
}

fn clang(
    text: &str,
    assume_filename: Option<&str>,
    lines: Option<(u32, u32)>,
) -> Result<String, EngineError> {
    let assume = assume_filename.map(|name| format!("--assume-filename={name}"));
    let span = lines.map(|(from, to)| format!("--lines={from}:{to}"));
    let mut args = Vec::new();
    if let Some(flag) = assume.as_deref() {
        args.push(flag);
    }
    if let Some(flag) = span.as_deref() {
        args.push(flag);
    }
    run("clang-format", args, text)
}

fn format_cmake(text: &str) -> Result<String, EngineError> {
    if find_tool("cmake-format").is_some() {
        return run("cmake-format", ["-"], text);
    }
    run("gersemi", ["-"], text)
}

pub fn selection_span(start: Option<u32>, end: Option<u32>) -> Option<(u32, u32)> {
    match (start, end) {
        (None, None) => None,
        (Some(s), Some(e)) => Some((s.min(e), s.max(e))),
        (Some(s), None) | (None, Some(s)) => Some((s, s)),
    }
}

fn line_range(text: &str, start_byte: u32, end_byte: u32) -> (u32, u32) {
    let start = clamp_byte(text, start_byte);
    let end = clamp_byte(text, end_byte).max(start);
    let last = if end > start { end - 1 } else { start };
    (line_at(text, start), line_at(text, last))
}

fn line_at(text: &str, byte: usize) -> u32 {
    let n = text.as_bytes()[..byte.min(text.len())]
        .iter()
        .filter(|b| **b == b'\n')
        .count() as u32;
    n + 1
}

fn clamp_byte(text: &str, byte: u32) -> usize {
    let mut b = (byte as usize).min(text.len());
    while b > 0 && !text.is_char_boundary(b) {
        b -= 1;
    }
    b
}
