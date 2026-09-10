use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::error::EngineError;
use crate::ffi::OutlineItem;

use super::includes::IncludeRef;
use super::syntax::{Lang, make};
use super::types::TypeTable;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileSummary {
    pub outline: Vec<OutlineItem>,
    pub includes: Vec<IncludeRef>,
    pub types: TypeTable,
}

pub fn summarize(path: &Path, text: &str) -> Result<FileSummary, EngineError> {
    summarize_as(path, text, Lang::for_buffer(path.to_str(), text))
}

pub fn summarize_header(path: &Path, text: &str) -> Result<FileSummary, EngineError> {
    let lang = match path.extension() {
        None => Lang::Cpp,
        Some(_) => Lang::for_buffer(path.to_str(), text),
    };
    summarize_as(path, text, lang)
}

fn summarize_as(path: &Path, text: &str, lang: Lang) -> Result<FileSummary, EngineError> {
    let mut syntax = make(lang)?;
    syntax.parse_full(text)?;
    Ok(FileSummary {
        outline: syntax.outline(text),
        includes: syntax.includes(text),
        types: syntax.type_table(text).with_origin(path),
    })
}
