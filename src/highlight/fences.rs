use tree_sitter::{Node, Parser, Query, Range, Tree};

use crate::error::EngineError;
use crate::ffi::{ByteRange, HighlightSpan};

use super::spans;
use super::syntax::parse_failed;

pub struct RustFences {
    parser: Parser,
    query: Query,
    tree: Option<Tree>,
    ranges: Vec<Range>,
}

impl RustFences {
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
            ranges: Vec::new(),
        })
    }

    pub fn reparse(&mut self, block_root: Node<'_>, text: &str) -> Result<(), EngineError> {
        self.ranges.clear();
        collect(block_root, text, &mut self.ranges);
        if self.ranges.is_empty() {
            self.tree = None;
            return Ok(());
        }
        self.parser
            .set_included_ranges(&self.ranges)
            .map_err(|e| EngineError::InvalidEdit {
                message: format!("{e:?}"),
            })?;
        self.tree = Some(self.parser.parse(text, None).ok_or_else(parse_failed)?);
        Ok(())
    }

    pub fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan> {
        let Some(tree) = &self.tree else {
            return Vec::new();
        };
        let clipped: Vec<ByteRange> = ranges
            .iter()
            .flat_map(|r| {
                self.ranges.iter().filter_map(move |f| {
                    let start = r.start_byte.max(f.start_byte as u32);
                    let end = r.end_byte.min(f.end_byte as u32);
                    (start < end).then_some(ByteRange {
                        start_byte: start,
                        end_byte: end,
                    })
                })
            })
            .collect();
        spans::highlights_in(&self.query, tree, text, &clipped)
    }
}

pub fn is_rust_fence(info: &str) -> bool {
    let lang = info.trim().split([',', ' ', '{']).next().unwrap_or("");
    matches!(lang, "rust" | "rs")
}

fn collect(node: Node<'_>, text: &str, out: &mut Vec<Range>) {
    if node.kind() == "fenced_code_block" {
        let mut cursor = node.walk();
        let children: Vec<Node<'_>> = node.named_children(&mut cursor).collect();
        let info = children
            .iter()
            .find(|c| c.kind() == "info_string")
            .and_then(|c| c.utf8_text(text.as_bytes()).ok())
            .unwrap_or("");
        if is_rust_fence(info)
            && let Some(content) = children.iter().find(|c| c.kind() == "code_fence_content")
        {
            out.push(content.range());
        }
        return;
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        collect(child, text, out);
    }
}
