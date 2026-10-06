#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct AiSnippet {
    pub path: String,
    pub line: u32,
    pub label: String,
    pub text: String,
    pub truncated: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct AiContext {
    pub path: String,
    pub language: String,
    pub focus: AiSnippet,
    pub enclosing: Option<AiSnippet>,
    pub related: Vec<AiSnippet>,
}
