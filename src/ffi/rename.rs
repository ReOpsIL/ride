use super::edit::TextEdit;

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct RenameFile {
    pub path: String,
    pub edits: Vec<TextEdit>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct RenamePlan {
    pub name: String,
    pub new_name: String,
    pub files: Vec<RenameFile>,
    pub review: Vec<RenameFile>,
}

impl RenamePlan {
    pub fn empty() -> Self {
        Self {
            name: String::new(),
            new_name: String::new(),
            files: Vec::new(),
            review: Vec::new(),
        }
    }
}
