use std::path::Path;

use crate::ffi::{Diagnostic, DiagnosticLevel};

use super::dedup::Seen;
use super::fixes::fixes;
use super::labels;
use super::message::{self, CargoLine, CompilerMessage, Span};
use super::notes;

pub fn parse_lines(root: &Path, text: &str) -> Vec<Diagnostic> {
    let mut seen = Seen::default();
    text.lines()
        .flat_map(|line| parse_message_line(root, line))
        .filter(|diagnostic| seen.accepts(diagnostic))
        .collect()
}

pub fn parse_message_line(root: &Path, line: &str) -> Vec<Diagnostic> {
    serde_json::from_str::<CargoLine>(line)
        .ok()
        .filter(|parsed| parsed.reason == "compiler-message")
        .and_then(|parsed| parsed.message)
        .map(|message| diagnostics(root, message))
        .unwrap_or_default()
}

fn diagnostics(root: &Path, message: CompilerMessage) -> Vec<Diagnostic> {
    let Some(level) = message::level(&message.level) else {
        return Vec::new();
    };
    let code = message.code.as_ref().map(|item| item.code.clone());
    message
        .spans
        .iter()
        .filter(|span| span.is_primary)
        .map(|span| one(root, &message, level, code.clone(), span))
        .collect()
}

fn one(
    root: &Path,
    message: &CompilerMessage,
    level: DiagnosticLevel,
    code: Option<String>,
    span: &Span,
) -> Diagnostic {
    let primary = labels::primary(root, span);
    let path = primary.path.clone();
    Diagnostic {
        level,
        message: message.message.clone(),
        code,
        primary,
        secondary: labels::secondary(root, &message.spans, &path),
        notes: notes::notes(root, &message.children, &path),
        fixes: fixes(root, &message.children, &path),
    }
}
