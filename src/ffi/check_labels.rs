#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct DiagnosticLabel {
    pub path: String,
    pub byte_start: u32,
    pub byte_end: u32,
    pub line_start: u32,
    pub line_end: u32,
    pub column: u32,
    pub text: Option<String>,
    pub macro_name: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct DiagnosticNote {
    pub level: super::check::DiagnosticLevel,
    pub message: String,
    pub labels: Vec<DiagnosticLabel>,
}
