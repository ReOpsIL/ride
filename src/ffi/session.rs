use serde::{Deserialize, Serialize};

use super::kind::{CaptureKind, ItemKind};
use crate::highlight::Lang;

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct ByteRange {
    pub start_byte: u32,
    pub end_byte: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct InputEditFfi {
    pub start_byte: u32,
    pub old_end_byte: u32,
    pub new_end_byte: u32,
    pub start_row: u32,
    pub start_column: u32,
    pub old_end_row: u32,
    pub old_end_column: u32,
    pub new_end_row: u32,
    pub new_end_column: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct HighlightSpan {
    pub start_byte: u32,
    pub end_byte: u32,
    pub capture: CaptureKind,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, uniffi::Record)]
pub struct OutlineItem {
    pub name: String,
    pub kind: ItemKind,
    pub start_byte: u32,
    pub end_byte: u32,
    pub signature: String,
    pub doc: String,
}

impl OutlineItem {
    pub fn new(name: String, kind: ItemKind, start_byte: u32, end_byte: u32) -> Self {
        Self {
            name,
            kind,
            start_byte,
            end_byte,
            signature: String::new(),
            doc: String::new(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct ParseErrorSpan {
    pub start_byte: u32,
    pub end_byte: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct SessionUpdate {
    pub session_generation: u64,
    pub changed: Vec<ByteRange>,
    pub highlights: Vec<HighlightSpan>,
    pub outline: Option<Vec<OutlineItem>>,
    pub errors: Vec<ParseErrorSpan>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct SessionOpen {
    pub session_id: u64,
    pub lang: Lang,
    pub update: SessionUpdate,
}

impl SessionUpdate {
    pub fn empty(generation: u64) -> Self {
        Self {
            session_generation: generation,
            changed: Vec::new(),
            highlights: Vec::new(),
            outline: None,
            errors: Vec::new(),
        }
    }
}
