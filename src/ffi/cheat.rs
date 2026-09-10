#[derive(Debug, Clone, uniffi::Record)]
pub struct CheatEntry {
    pub name: String,
    pub doc: String,
    pub snippet: String,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CheatSection {
    pub title: String,
    pub matched: bool,
    pub entries: Vec<CheatEntry>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CheatSheetResponse {
    pub sections: Vec<CheatSection>,
    pub replace_start_byte: u32,
    pub prefix: String,
    pub context: String,
}

impl CheatSheetResponse {
    pub fn empty(at: u32) -> Self {
        Self {
            sections: Vec::new(),
            replace_start_byte: at,
            prefix: String::new(),
            context: "unknown".into(),
        }
    }
}
