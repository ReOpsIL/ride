use super::edit::TextEdit;

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ExtractPlan {
    pub edits: Vec<TextEdit>,
    pub name: String,
    pub select_start: u32,
    pub select_end: u32,
}
