use super::check_labels::{DiagnosticLabel, DiagnosticNote};
use super::edit::TextEdit;

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum DiagnosticLevel {
    Error,
    Warning,
    Note,
    Help,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct Diagnostic {
    pub level: DiagnosticLevel,
    pub message: String,
    pub code: Option<String>,
    pub primary: DiagnosticLabel,
    pub secondary: Vec<DiagnosticLabel>,
    pub notes: Vec<DiagnosticNote>,
    pub fixes: Vec<DiagnosticFix>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct DiagnosticFix {
    pub title: String,
    pub edits: Vec<TextEdit>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CheckResult {
    pub success: bool,
    pub diagnostics: Vec<Diagnostic>,
    pub stderr_tail: String,
}
