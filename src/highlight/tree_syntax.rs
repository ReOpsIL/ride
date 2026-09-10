use std::sync::OnceLock;

use tree_sitter::{InputEdit, Parser, Query, Range, Tree};

use crate::error::EngineError;
use crate::ffi::{ByteRange, HighlightSpan, OutlineItem, ParseErrorSpan, SymbolAt};

use super::grammar::Grammar;
use super::includes::IncludeRef;
use super::members::{self, Access};
use super::ranges::from_ts;
use super::site::SiteAt;
use super::syntax::{LocalHits, LocalQuery, Syntax, lang_err, parse_failed, query_err};
use super::types::TypeTable;
use super::{errors, locals, spans, symbol};

pub struct TreeSyntax {
    grammar: Grammar,
    parser: Parser,
    query: OnceLock<Option<Query>>,
    tree: Option<Tree>,
}

impl TreeSyntax {
    pub fn new(grammar: Grammar) -> Result<Self, EngineError> {
        let mut parser = Parser::new();
        parser.set_language(&grammar.language).map_err(lang_err)?;
        Ok(Self {
            grammar,
            parser,
            query: OnceLock::new(),
            tree: None,
        })
    }

    fn query(&self) -> Option<&Query> {
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
            .zip(self.query())
            .map(|(t, query)| spans::highlights(query, t, text, ranges))
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

    fn local_hits(&self, text: &str, outline: &[OutlineItem], q: &LocalQuery<'_>) -> LocalHits {
        let Some(tree) = self.tree.as_ref() else {
            return LocalHits::default();
        };
        let limit = q.limit as usize;
        match members::access_before(tree, text, q.at as usize, self.grammar.member_ops) {
            Some(receiver) => LocalHits {
                hits: members::fallback_hits(tree, text, outline, q.prefix, limit, &self.grammar),
                access: Some(Access {
                    chain: receiver.and_then(|r| (self.grammar.receiver)(tree, text, r)),
                }),
            },
            None => LocalHits {
                hits: locals::hits(tree, text, outline, q, &self.grammar),
                access: None,
            },
        }
    }

    fn includes(&self, text: &str) -> Vec<IncludeRef> {
        self.tree
            .as_ref()
            .map(|t| (self.grammar.includes)(t, text))
            .unwrap_or_default()
    }

    fn type_table(&self, text: &str) -> TypeTable {
        self.tree
            .as_ref()
            .map(|t| (self.grammar.type_table)(t, text))
            .unwrap_or_default()
    }

    fn site_at(&self, text: &str, at: usize) -> SiteAt {
        (self.grammar.site)(self.tree.as_ref(), text, at.min(text.len()))
    }

    fn imports(&self, text: &str) -> Vec<String> {
        self.tree
            .as_ref()
            .map(|t| (self.grammar.imports)(t, text))
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
