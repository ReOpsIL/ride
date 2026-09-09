use std::collections::HashSet;
use std::path::Path;

use crate::ffi::{Diagnostic, DiagnosticLevel};

use super::message::{CargoLine, CompilerMessage};

pub fn parse_lines(root: &Path, text: &str) -> Vec<Diagnostic> {
    let mut seen = HashSet::new();
    text.lines()
        .filter_map(|line| serde_json::from_str::<CargoLine>(line).ok())
        .filter(|l| l.reason == "compiler-message")
        .filter_map(|l| l.message)
        .flat_map(|m| diagnostics(root, m))
        .filter(|d| seen.insert((d.path.clone(), d.byte_start, d.message.clone())))
        .collect()
}

fn diagnostics(root: &Path, m: CompilerMessage) -> Vec<Diagnostic> {
    let Some(level) = level(&m.level) else {
        return Vec::new();
    };
    let code = m.code.map(|c| c.code);
    m.spans
        .into_iter()
        .filter(|s| s.is_primary)
        .map(|s| Diagnostic {
            path: absolute(root, &s.file_name),
            byte_start: s.byte_start,
            byte_end: s.byte_end.max(s.byte_start),
            line: s.line_start,
            column: s.column_start,
            level,
            message: m.message.clone(),
            code: code.clone(),
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

fn absolute(root: &Path, file: &str) -> String {
    let p = Path::new(file);
    if p.is_absolute() {
        return p.display().to_string();
    }
    root.join(p).display().to_string()
}
