use std::sync::OnceLock;

use tree_sitter::{Parser, Query, Range, Tree};

use crate::error::EngineError;

use super::grammar::Grammar;
use super::syntax::{lang_err, query_err};

pub struct TreeSyntax {
    pub(super) grammar: Grammar,
    pub(super) parser: Parser,
    pub(super) tree: Option<Tree>,
    query: OnceLock<Option<Query>>,
}

impl TreeSyntax {
    pub fn new(grammar: Grammar) -> Result<Self, EngineError> {
        let mut parser = Parser::new();
        parser.set_language(&grammar.language).map_err(lang_err)?;
        Ok(Self {
            grammar,
            parser,
            tree: None,
            query: OnceLock::new(),
        })
    }

    pub(super) fn query(&self) -> Option<&Query> {
        self.query
            .get_or_init(|| {
                Query::new(&self.grammar.language, self.grammar.highlights)
                    .map_err(query_err)
                    .ok()
            })
            .as_ref()
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
