use tree_sitter::{InputEdit, Parser, Query, Range, Tree};

use crate::error::EngineError;
use crate::ffi::{ByteRange, CompletionHit, HighlightSpan, OutlineItem, ParseErrorSpan, SymbolAt};

use super::grammar::Grammar;
use super::ranges::from_ts;
use super::syntax::{Syntax, lang_err, parse_failed, query_err};
use super::{errors, locals, spans, symbol};

pub struct TreeSyntax {
    grammar: Grammar,
    parser: Parser,
    query: Query,
    tree: Option<Tree>,
}

impl TreeSyntax {
    pub fn new(grammar: Grammar) -> Result<Self, EngineError> {
        let mut parser = Parser::new();
        parser.set_language(&grammar.language).map_err(lang_err)?;
        let query = Query::new(&grammar.language, grammar.highlights).map_err(query_err)?;
        Ok(Self {
            grammar,
            parser,
            query,
            tree: None,
        })
    }

    pub fn set_included_ranges(&mut self, ranges: &[Range]) -> Result<(), EngineError> {
        self.parser
            .set_included_ranges(ranges)
            .map_err(|e| EngineError::InvalidEdit {
                message: format!("{e:?}"),
            })
    }

    pub fn clear(&mut self) {
        self.tree = None;
    }
}

impl Syntax for TreeSyntax {
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
        self.tree
            .as_ref()
            .map(|t| (self.grammar.outline)(t, text))
            .unwrap_or_default()
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
            .map(|t| locals::hits(t, text, outline, prefix, limit, self.grammar.local_kinds))
            .unwrap_or_default()
    }

    fn symbol_at(&self, text: &str, byte: u32) -> Option<SymbolAt> {
        let tree = self.tree.as_ref()?;
        symbol::symbol_at(
            tree,
            text,
            byte,
            self.grammar.symbol_kinds,
            self.grammar.qualifier,
        )
    }
}
