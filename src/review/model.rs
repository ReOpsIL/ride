#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Change {
    Body,
    Signature,
    Added,
    Removed,
    Moved,
    File,
}

impl Change {
    pub fn label(self) -> &'static str {
        match self {
            Self::Body => "body",
            Self::Signature => "signature",
            Self::Added => "added",
            Self::Removed => "removed",
            Self::Moved => "moved",
            Self::File => "file",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Group {
    Behaviour,
    Light,
    Equivalent,
}

impl Group {
    pub fn label(self) -> &'static str {
        match self {
            Self::Behaviour => "behaviour",
            Self::Light => "light",
            Self::Equivalent => "equivalent",
        }
    }

    pub fn rank(self) -> u8 {
        match self {
            Self::Behaviour => 0,
            Self::Light => 1,
            Self::Equivalent => 2,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LineRange {
    pub start: u32,
    pub end: u32,
}

#[derive(Debug, Clone, Default)]
pub struct Hunks {
    pub old: Vec<LineRange>,
    pub new: Vec<LineRange>,
}

#[derive(Debug, Clone)]
pub struct FileInput {
    pub path: String,
    pub old_text: Option<String>,
    pub new_text: Option<String>,
    pub binary: bool,
    pub hunks: Option<Hunks>,
}

#[derive(Debug, Clone)]
pub struct Row {
    pub path: String,
    pub old_path: String,
    pub item: String,
    pub name: String,
    pub kind: String,
    pub change: Change,
    pub group: Group,
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
    pub is_test: bool,
    pub verified_fresh: bool,
    pub open_suspect: bool,
    pub open_question: bool,
    pub mark: String,
    pub mark_author: String,
    pub mark_state: String,
    pub mark_note: String,
    pub mark_id: String,
}

impl Row {
    pub fn covered(&self) -> bool {
        self.verified_fresh || self.open_suspect || self.open_question
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Counts {
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
}

#[derive(Debug, Clone)]
pub struct Candidate {
    pub path: String,
    pub item: String,
    pub kind: String,
    pub shape: String,
    pub name: String,
    pub line: u32,
}

#[derive(Debug, Clone)]
pub struct CallSite {
    pub name: String,
    pub path: String,
    pub line: u32,
}

#[derive(Debug, Clone)]
pub struct Inbox {
    pub base: String,
    pub head: String,
    pub upstream: String,
    pub order: String,
    pub grouped: bool,
    pub counts: Counts,
    pub rows: Vec<Row>,
}

#[derive(Debug, Clone)]
pub struct Built {
    pub inbox: Inbox,
    pub items: Vec<Candidate>,
    pub calls: Vec<CallSite>,
    pub shapes: Vec<String>,
}

pub fn module_of(path: &str) -> String {
    match path.rfind('/') {
        Some(index) if index > 0 => path[..index].to_string(),
        _ => String::new(),
    }
}

pub fn skipped(path: &str) -> bool {
    path == ".ride" || path.starts_with(".ride/") || path.contains("/.ride/")
}
