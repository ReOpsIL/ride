use tree_sitter::InputEdit;

use crate::error::EngineError;
use crate::ffi::{
    BracketPair, ByteRange, CompletionHit, FoldRange, HighlightSpan, OutlineItem, ParseErrorSpan,
    SymbolAt,
};

use super::context::Context;
use super::includes::IncludeRef;
use super::members::Access;
use super::site::SiteAt;
use super::types::TypeTable;

pub use super::lang::Lang;

#[derive(Debug, Clone, Copy)]
pub struct LocalQuery<'a> {
    pub prefix: &'a str,
    pub limit: u32,
    pub at: u32,
}

#[derive(Debug, Clone, Default)]
pub struct LocalHits {
    pub hits: Vec<CompletionHit>,
    pub access: Option<Access>,
}

pub trait Syntax: Send + Sync {
    fn parse_full(&mut self, text: &str) -> Result<(), EngineError>;
    fn edit(&mut self, edit: &InputEdit, text: &str) -> Result<Vec<ByteRange>, EngineError>;
    fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan>;
    fn outline(&self, text: &str) -> Vec<OutlineItem>;
    fn errors(&self) -> Vec<ParseErrorSpan>;
    fn local_hits(&self, text: &str, outline: &[OutlineItem], q: &LocalQuery<'_>) -> LocalHits;
    fn symbol_at(&self, text: &str, byte: u32) -> Option<SymbolAt>;
    fn includes(&self, _text: &str) -> Vec<IncludeRef> {
        Vec::new()
    }
    fn type_table(&self, _text: &str) -> TypeTable {
        TypeTable::default()
    }
    fn site_at(&self, _text: &str, at: usize) -> SiteAt {
        SiteAt::none(at)
    }
    fn context_at(&self, _text: &str, _at: usize) -> Context {
        Context::Unknown
    }
    fn imports(&self, _text: &str) -> Vec<String> {
        Vec::new()
    }
    fn postfix_receiver(&self, _text: &str, _replace_start: usize) -> Option<(usize, usize)> {
        None
    }
    fn enclosing_ranges(&self, _text: &str, _range: ByteRange) -> Vec<ByteRange> {
        Vec::new()
    }
    fn fold_ranges(&self, _text: &str) -> Vec<FoldRange> {
        Vec::new()
    }
    fn bracket_pair(&self, _text: &str, _byte: usize) -> Option<BracketPair> {
        None
    }
    fn statement_range(&self, _text: &str, _byte: u32) -> Option<ByteRange> {
        None
    }
    fn sibling_statement(&self, _text: &str, _byte: u32, _up: bool) -> Option<ByteRange> {
        None
    }
}

pub fn parse_failed() -> EngineError {
    EngineError::InvalidEdit {
        message: "parse returned none".into(),
    }
}

pub fn lang_err(e: tree_sitter::LanguageError) -> EngineError {
    EngineError::InvalidEdit {
        message: format!("{e:?}"),
    }
}

pub fn query_err(e: tree_sitter::QueryError) -> EngineError {
    EngineError::InvalidEdit {
        message: e.to_string(),
    }
}

pub fn make(lang: Lang) -> Result<Box<dyn Syntax>, EngineError> {
    Ok(match lang.grammar() {
        Some(grammar) => Box::new(super::tree_syntax::TreeSyntax::new(grammar)?),
        None => Box::new(super::markdown::MarkdownSyntax::new()?),
    })
}
