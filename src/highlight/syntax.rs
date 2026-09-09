use tree_sitter::InputEdit;

use crate::error::EngineError;
use crate::ffi::{ByteRange, CompletionHit, HighlightSpan, OutlineItem, ParseErrorSpan, SymbolAt};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Lang {
    Rust,
    Markdown,
}

impl Lang {
    pub fn for_path(path: Option<&str>) -> Lang {
        let ext = path
            .and_then(|p| p.rsplit_once('.'))
            .map(|(_, e)| e.to_ascii_lowercase());
        match ext.as_deref() {
            Some("md") | Some("markdown") => Lang::Markdown,
            _ => Lang::Rust,
        }
    }
}

pub trait Syntax: Send + Sync {
    fn parse_full(&mut self, text: &str) -> Result<(), EngineError>;
    fn edit(&mut self, edit: &InputEdit, text: &str) -> Result<Vec<ByteRange>, EngineError>;
    fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan>;
    fn outline(&self, text: &str) -> Vec<OutlineItem>;
    fn errors(&self) -> Vec<ParseErrorSpan>;
    fn local_hits(
        &self,
        text: &str,
        outline: &[OutlineItem],
        prefix: &str,
        limit: u32,
    ) -> Vec<CompletionHit>;
    fn symbol_at(&self, text: &str, byte: u32) -> Option<SymbolAt>;
}

pub fn parse_failed() -> EngineError {
    EngineError::InvalidEdit {
        message: "parse returned none".into(),
    }
}

pub fn make(lang: Lang) -> Result<Box<dyn Syntax>, EngineError> {
    Ok(match lang {
        Lang::Rust => Box::new(super::rust_syntax::RustSyntax::new()?),
        Lang::Markdown => Box::new(super::markdown::MarkdownSyntax::new()?),
    })
}
