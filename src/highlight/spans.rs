use tree_sitter::{Query, QueryCursor, StreamingIterator};

use crate::ffi::{ByteRange, CaptureKind, HighlightSpan};

use super::capture::capture_kind;

const HIGHLIGHTS: &str = include_str!("../../queries/rust/highlights.scm");

pub fn rust_highlights(code: &str) -> Result<Vec<HighlightSpan>, String> {
    let mut parser = tree_sitter::Parser::new();
    parser
        .set_language(&tree_sitter_rust::LANGUAGE.into())
        .map_err(|e| format!("{e:?}"))?;
    let tree = parser.parse(code, None).ok_or("parse returned none")?;
    let query = query()?;
    Ok(highlights(
        &query,
        &tree,
        code,
        &[ByteRange {
            start_byte: 0,
            end_byte: code.len() as u32,
        }],
    ))
}

pub fn query() -> Result<Query, String> {
    let lang = tree_sitter::Language::new(tree_sitter_rust::LANGUAGE);
    Query::new(&lang, HIGHLIGHTS).map_err(|e| e.to_string())
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
