#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ReviewMark {
    pub path: String,
    pub item: String,
    pub kind: String,
    pub mark: String,
    pub note: String,
    pub basis: String,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ReviewInbox {
    pub base: String,
    pub head: String,
    pub upstream: String,
    pub order: String,
    pub grouped: bool,
    pub needs_eyes: u32,
    pub verified: u32,
    pub suspect: u32,
    pub question: u32,
    pub unchecked: u32,
    pub equivalent: u32,
    pub light: u32,
    pub behaviour: u32,
    pub docs: u32,
    pub imports: u32,
    pub tests: u32,
    pub formatting: u32,
    pub moved: u32,
    pub rows: Vec<ReviewRow>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ReviewRow {
    pub path: String,
    pub old_path: String,
    pub item: String,
    pub name: String,
    pub kind: String,
    pub change: String,
    pub group: String,
    pub checks: Vec<String>,
    pub shape: String,
    pub start_byte: u32,
    pub end_byte: u32,
    pub line: u32,
    pub signature: String,
    pub doc: String,
    pub module: String,
    pub callers: u32,
    pub detail: String,
    pub mark: String,
    pub mark_author: String,
    pub mark_state: String,
    pub mark_note: String,
    pub mark_id: String,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ReviewMarkLine {
    pub id: String,
    pub text: String,
    pub own: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ReviewDossier {
    pub signature: String,
    pub doc: String,
    pub line: u32,
    pub change: String,
    pub checks: Vec<String>,
    pub callers: Vec<String>,
    pub callees: Vec<String>,
    pub claims: Vec<String>,
    pub marks: Vec<ReviewMarkLine>,
    pub since: Vec<String>,
    pub note: String,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ReviewHunt {
    pub path: String,
    pub item: String,
    pub name: String,
    pub checks: u32,
    pub on_stack: bool,
    pub open_mark: bool,
    pub failing: String,
    pub base_label: String,
}
