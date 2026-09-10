#[derive(Debug, Clone, uniffi::Record)]
pub struct ToolInfo {
    pub name: String,
    pub purpose: String,
    pub path: Option<String>,
    pub install: Option<String>,
    pub hint: String,
}
