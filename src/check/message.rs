use serde::Deserialize;

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
    pub column_start: u32,
    pub is_primary: bool,
}
