use super::edit::TextEdit;

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct Intention {
    pub id: u32,
    pub title: String,
    pub edits: Vec<TextEdit>,
}
