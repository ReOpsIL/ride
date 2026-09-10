use tree_sitter::{Query, QueryCursor, StreamingIterator};

use crate::error::EngineError;
use crate::ffi::{ByteRange, CaptureKind, HighlightSpan};

use super::capture::capture_kind;
use super::syntax::{Lang, make};

pub fn source_highlights(lang: Lang, code: &str) -> Result<Vec<HighlightSpan>, EngineError> {
    let mut syntax = make(lang)?;
    syntax.parse_full(code)?;
    Ok(syntax.highlights(
        code,
        &[ByteRange {
            start_byte: 0,
            end_byte: code.len() as u32,
        }],
    ))
}

pub fn highlights(
    query: &Query,
    tree: &tree_sitter::Tree,
    text: &str,
    ranges: &[ByteRange],
) -> Vec<HighlightSpan> {
    let mut out = highlights_in(query, tree, text, ranges);
    out.sort_by_key(|s| (s.start_byte, s.end_byte, std::cmp::Reverse(rank(s.capture))));
    out.dedup_by(|a, b| a.start_byte == b.start_byte && a.end_byte == b.end_byte);
    out
}

pub fn highlights_in(
    query: &Query,
    tree: &tree_sitter::Tree,
    text: &str,
    ranges: &[ByteRange],
) -> Vec<HighlightSpan> {
    if ranges.is_empty() {
        return Vec::new();
    }
    let mut cursor = QueryCursor::new();
    let mut out = Vec::new();
    for range in ranges {
        cursor.set_byte_range(range.start_byte as usize..range.end_byte as usize);
        let mut captures = cursor.captures(query, tree.root_node(), text.as_bytes());
        while let Some((m, cap_i)) = captures.next() {
            let cap = m.captures()[*cap_i];
            let name = query.capture_names()[cap.index as usize];
            let kind = capture_kind(name);
            if kind == CaptureKind::Punctuation && name.contains("bracket") {
                continue;
            }
            out.push(HighlightSpan {
                start_byte: cap.node.start_byte() as u32,
                end_byte: cap.node.end_byte() as u32,
                capture: kind,
            });
        }
    }
    out
}

fn rank(kind: CaptureKind) -> u8 {
    match kind {
        CaptureKind::Variable => 0,
        CaptureKind::Property => 1,
        CaptureKind::Function => 2,
        CaptureKind::Type => 3,
        CaptureKind::Constant => 4,
        CaptureKind::Number => 5,
        CaptureKind::String | CaptureKind::Escape => 6,
        CaptureKind::Attribute | CaptureKind::Lifetime | CaptureKind::Label => 7,
        CaptureKind::Macro => 8,
        CaptureKind::Keyword => 9,
        CaptureKind::Comment => 10,
        CaptureKind::Heading => 3,
        CaptureKind::Emphasis | CaptureKind::Strong | CaptureKind::Link => 5,
        CaptureKind::Operator | CaptureKind::Punctuation => 1,
    }
}
