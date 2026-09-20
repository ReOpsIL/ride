use std::path::Path;

use crate::abspath::absolute_string;
use crate::ffi::{Diagnostic, DiagnosticLevel};

use super::dedup::Seen;
use super::fixes::fixes;
use super::message::{CargoLine, CompilerMessage};

pub fn parse_lines(root: &Path, text: &str) -> Vec<Diagnostic> {
    let mut seen = Seen::default();
    text.lines()
        .flat_map(|line| parse_message_line(root, line))
        .filter(|d| seen.accepts(d))
        .collect()
}

pub fn parse_message_line(root: &Path, line: &str) -> Vec<Diagnostic> {
    serde_json::from_str::<CargoLine>(line)
        .ok()
        .filter(|l| l.reason == "compiler-message")
        .and_then(|l| l.message)
        .map(|m| diagnostics(root, m))
        .unwrap_or_default()
}

fn diagnostics(root: &Path, m: CompilerMessage) -> Vec<Diagnostic> {
    let Some(level) = level(&m.level) else {
        return Vec::new();
    };
    let code = m.code.map(|c| c.code);
    let children = m.children;
    m.spans
        .into_iter()
        .filter(|s| s.is_primary)
        .map(|s| {
            let path = absolute_string(root, &s.file_name);
            let fixes = fixes(root, &children, &path);
            Diagnostic {
                path,
                byte_start: s.byte_start,
                byte_end: s.byte_end.max(s.byte_start),
                line: s.line_start,
                column: s.column_start,
                level,
                message: m.message.clone(),
                code: code.clone(),
                fixes,
            }
        })
        .collect()
}

fn level(label: &str) -> Option<DiagnosticLevel> {
    match label {
        "error" => Some(DiagnosticLevel::Error),
        "warning" => Some(DiagnosticLevel::Warning),
        "note" => Some(DiagnosticLevel::Note),
        "help" => Some(DiagnosticLevel::Help),
        _ => None,
    }
}
