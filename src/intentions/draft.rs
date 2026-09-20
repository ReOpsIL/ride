use crate::ffi::{Intention, TextEdit};

pub struct Draft {
    pub title: String,
    pub edits: Vec<TextEdit>,
}

impl Draft {
    pub fn new(title: impl Into<String>, edits: Vec<TextEdit>) -> Self {
        Self {
            title: title.into(),
            edits,
        }
    }
}

pub fn number(drafts: Vec<Draft>) -> Vec<Intention> {
    drafts
        .into_iter()
        .filter(|draft| !draft.edits.is_empty())
        .enumerate()
        .map(|(index, draft)| Intention {
            id: index as u32,
            title: draft.title,
            edits: draft.edits,
        })
        .collect()
}
