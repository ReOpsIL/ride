#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum DiagnosticLevel {
    Error,
    Warning,
    Note,
    Help,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct Diagnostic {
    pub path: String,
    pub byte_start: u32,
    pub byte_end: u32,
    pub line: u32,
    pub column: u32,
    pub level: DiagnosticLevel,
    pub message: String,
    pub code: Option<String>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CheckResult {
    pub success: bool,
    pub diagnostics: Vec<Diagnostic>,
    pub stderr_tail: String,
}
