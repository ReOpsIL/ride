use tree_sitter::{InputEdit, Node, Parser, Query, Range, Tree};

use crate::error::EngineError;
use crate::ffi::{
    ByteRange, CompletionHit, HighlightSpan, ItemKind, OutlineItem, ParseErrorSpan, SymbolAt,
};

use super::fences::Fences;
use super::ranges::from_ts;
use super::spans::highlights_in;
use super::syntax::{Syntax, lang_err, parse_failed, query_err};

const BLOCK_QUERY: &str = include_str!("../../queries/markdown/block.scm");
const INLINE_QUERY: &str = include_str!("../../queries/markdown/inline.scm");

pub struct MarkdownSyntax {
    block: Parser,
    inline: Parser,
    block_query: Query,
    inline_query: Query,
    block_tree: Option<Tree>,
    inline_tree: Option<Tree>,
    fences: Fences,
}

impl MarkdownSyntax {
    pub fn new() -> Result<Self, EngineError> {
        let block_lang = tree_sitter::Language::new(tree_sitter_md::LANGUAGE);
        let inline_lang = tree_sitter::Language::new(tree_sitter_md::INLINE_LANGUAGE);
        let mut block = Parser::new();
        let mut inline = Parser::new();
        block.set_language(&block_lang).map_err(lang_err)?;
        inline.set_language(&inline_lang).map_err(lang_err)?;
        let block_query = Query::new(&block_lang, BLOCK_QUERY).map_err(query_err)?;
        let inline_query = Query::new(&inline_lang, INLINE_QUERY).map_err(query_err)?;
        Ok(Self {
            block,
            inline,
            block_query,
            inline_query,
            block_tree: None,
            inline_tree: None,
            fences: Fences::new()?,
        })
    }

    fn parse_inline(&mut self, text: &str) -> Result<(), EngineError> {
        let Some(block) = self.block_tree.as_ref() else {
            return Ok(());
        };
        self.fences.reparse(block.root_node(), text)?;
        let mut ranges = Vec::new();
        collect_inline(block.root_node(), &mut ranges);
        if ranges.is_empty() {
            self.inline_tree = None;
            return Ok(());
        }
        self.inline
            .set_included_ranges(&ranges)
            .map_err(|e| EngineError::InvalidEdit {
                message: format!("{e:?}"),
            })?;
        self.inline_tree = Some(self.inline.parse(text, None).ok_or_else(parse_failed)?);
        Ok(())
    }
}

impl Syntax for MarkdownSyntax {
    fn parse_full(&mut self, text: &str) -> Result<(), EngineError> {
        self.block_tree = Some(self.block.parse(text, None).ok_or_else(parse_failed)?);
        self.parse_inline(text)
    }

    fn edit(&mut self, edit: &InputEdit, text: &str) -> Result<Vec<ByteRange>, EngineError> {
        let Some(old) = self.block_tree.as_mut() else {
            self.parse_full(text)?;
            return Ok(vec![from_ts(0, text.len())]);
        };
        old.edit(edit);
        let new_tree = self.block.parse(text, Some(old)).ok_or_else(parse_failed)?;
        let mut changed: Vec<ByteRange> = old
            .changed_ranges(&new_tree)
            .map(|r| from_ts(r.start_byte, r.end_byte))
            .collect();
        if let Some(block) = enclosing_block(new_tree.root_node(), edit) {
            changed.push(from_ts(block.start_byte(), block.end_byte()));
        }
        self.block_tree = Some(new_tree);
        self.parse_inline(text)?;
        let mut merged = Vec::new();
        super::ranges::union_into(&mut merged, &changed);
        Ok(merged)
    }

    fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan> {
        let mut out = Vec::new();
        if let Some(tree) = &self.block_tree {
            out.extend(highlights_in(&self.block_query, tree, text, ranges));
        }
        if let Some(tree) = &self.inline_tree {
            out.extend(highlights_in(&self.inline_query, tree, text, ranges));
        }
        out.extend(self.fences.highlights(text, ranges));
        out.sort_by_key(|s| (s.start_byte, s.end_byte));
        out
    }

    fn outline(&self, text: &str) -> Vec<OutlineItem> {
        let Some(tree) = &self.block_tree else {
            return Vec::new();
        };
        let mut out = Vec::new();
        headings(tree.root_node(), text, &mut out);
        out
    }

    fn errors(&self) -> Vec<ParseErrorSpan> {
        Vec::new()
    }

    fn local_hits(&self, _: &str, _: &[OutlineItem], _: &str, _: u32) -> Vec<CompletionHit> {
        Vec::new()
    }

    fn symbol_at(&self, _: &str, _: u32) -> Option<SymbolAt> {
        None
    }
}

fn collect_inline(node: Node<'_>, out: &mut Vec<Range>) {
    if node.kind() == "inline" {
        out.push(node.range());
        return;
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        collect_inline(child, out);
    }
}

fn enclosing_block<'a>(root: Node<'a>, edit: &InputEdit) -> Option<Node<'a>> {
    let mut node =
        root.descendant_for_byte_range(edit.start_byte, edit.new_end_byte.max(edit.start_byte))?;
    while let Some(parent) = node.parent() {
        if matches!(parent.kind(), "document" | "section") {
            break;
        }
        node = parent;
    }
    Some(node)
}

fn headings(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    if matches!(node.kind(), "atx_heading" | "setext_heading") {
        let name = node
            .named_children(&mut node.walk())
            .find(|c| c.kind() == "inline" || c.kind() == "paragraph")
            .and_then(|c| c.utf8_text(text.as_bytes()).ok())
            .unwrap_or("")
            .trim()
            .to_string();
        out.push(OutlineItem {
            name,
            kind: ItemKind::Heading,
            start_byte: node.start_byte() as u32,
            end_byte: node.end_byte() as u32,
        });
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        headings(child, text, out);
    }
}
