use tree_sitter::{InputEdit, Parser, Query, Tree};

use crate::error::EngineError;
use crate::ffi::{ByteRange, CompletionHit, HighlightSpan, OutlineItem, ParseErrorSpan, SymbolAt};

use super::ranges::from_ts;
use super::syntax::{Syntax, parse_failed};
use super::{errors, locals, outline, spans, symbol};

pub struct RustSyntax {
    parser: Parser,
    query: Query,
    tree: Option<Tree>,
}

impl RustSyntax {
    pub fn new() -> Result<Self, EngineError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_rust::LANGUAGE.into())
            .map_err(|e| EngineError::InvalidEdit {
                message: format!("{e:?}"),
            })?;
        let query = spans::query().map_err(|message| EngineError::InvalidEdit { message })?;
        Ok(Self {
            parser,
            query,
            tree: None,
        })
    }
}

impl Syntax for RustSyntax {
    fn parse_full(&mut self, text: &str) -> Result<(), EngineError> {
        self.tree = Some(self.parser.parse(text, None).ok_or_else(parse_failed)?);
        Ok(())
    }

    fn edit(&mut self, edit: &InputEdit, text: &str) -> Result<Vec<ByteRange>, EngineError> {
        let Some(old) = self.tree.as_mut() else {
            self.parse_full(text)?;
            return Ok(vec![from_ts(0, text.len())]);
        };
        old.edit(edit);
        let new_tree = self
            .parser
            .parse(text, Some(old))
            .ok_or_else(parse_failed)?;
        let changed = old
            .changed_ranges(&new_tree)
            .map(|r| from_ts(r.start_byte, r.end_byte))
            .collect();
        self.tree = Some(new_tree);
        Ok(changed)
    }

    fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan> {
        self.tree
            .as_ref()
            .map(|t| spans::highlights(&self.query, t, text, ranges))
            .unwrap_or_default()
    }

    fn outline(&self, text: &str) -> Vec<OutlineItem> {
        outline::from_source(text).unwrap_or_default()
    }

    fn errors(&self) -> Vec<ParseErrorSpan> {
        self.tree
            .as_ref()
            .map(|t| errors::collect(t.root_node()))
            .unwrap_or_default()
    }

    fn local_hits(
        &self,
        text: &str,
        outline: &[OutlineItem],
        prefix: &str,
        limit: u32,
    ) -> Vec<CompletionHit> {
        self.tree
            .as_ref()
            .map(|t| locals::hits(t, text, outline, prefix, limit))
            .unwrap_or_default()
    }

    fn symbol_at(&self, text: &str, byte: u32) -> Option<SymbolAt> {
        self.tree
            .as_ref()
            .and_then(|t| symbol::symbol_at(t, text, byte))
    }
}
