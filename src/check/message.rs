use serde::Deserialize;

use crate::ffi::DiagnosticLevel;

#[derive(Deserialize)]
pub struct CargoLine {
    pub reason: String,
    pub message: Option<CompilerMessage>,
}

#[derive(Deserialize)]
pub struct CompilerMessage {
    pub message: String,
    pub level: String,
    pub code: Option<Code>,
    #[serde(default)]
    pub spans: Vec<Span>,
    #[serde(default)]
    pub children: Vec<CompilerMessage>,
}

#[derive(Deserialize)]
pub struct Code {
    pub code: String,
}

#[derive(Deserialize)]
pub struct Span {
    pub file_name: String,
    pub byte_start: u32,
    pub byte_end: u32,
    pub line_start: u32,
    pub line_end: u32,
    pub column_start: u32,
    pub column_end: u32,
    pub is_primary: bool,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub suggested_replacement: Option<String>,
    #[serde(default)]
    pub suggestion_applicability: Option<String>,
    #[serde(default)]
    pub expansion: Option<Box<Expansion>>,
}

#[derive(Deserialize)]
pub struct Expansion {
    pub span: Span,
    pub macro_decl_name: String,
}

pub(super) fn level(label: &str) -> Option<DiagnosticLevel> {
    match label {
        "error" => Some(DiagnosticLevel::Error),
        "warning" => Some(DiagnosticLevel::Warning),
        "note" => Some(DiagnosticLevel::Note),
        "help" => Some(DiagnosticLevel::Help),
        _ => None,
    }
}
