use std::path::Path;

use crate::error::EngineError;
use crate::ffi::OutlineItem;

use super::includes::IncludeRef;
use super::syntax::{Lang, make};
use super::types::TypeTable;

#[derive(Debug, Clone)]
pub struct FileSummary {
    pub outline: Vec<OutlineItem>,
    pub includes: Vec<IncludeRef>,
    pub types: TypeTable,
}

pub fn summarize(path: &Path, text: &str) -> Result<FileSummary, EngineError> {
    let lang = Lang::for_buffer(path.to_str(), text);
    let mut syntax = make(lang)?;
    syntax.parse_full(text)?;
    Ok(FileSummary {
        outline: syntax.outline(text),
        includes: syntax.includes(text),
        types: syntax.type_table(text).with_origin(path),
    })
}
