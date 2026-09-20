use tree_sitter::Node;

use crate::ffi::ByteRange;

const EXPRESSION_KINDS: [&str; 20] = [
    "binary_expression",
    "call_expression",
    "method_call_expression",
    "field_expression",
    "index_expression",
    "subscript_expression",
    "unary_expression",
    "parenthesized_expression",
    "identifier",
    "field_identifier",
    "scoped_identifier",
    "integer_literal",
    "float_literal",
    "string_literal",
    "char_literal",
    "boolean_literal",
    "number_literal",
    "true",
    "false",
    "raw_string_literal",
];

const BODY_KINDS: [&str; 2] = ["block", "compound_statement"];

pub struct ExtractSpans {
    pub expr: ByteRange,
    pub statement: ByteRange,
}

pub fn spans(root: Node<'_>, text: &str, range: ByteRange) -> Option<ExtractSpans> {
    let (start, end) = trimmed(text, range)?;
    let node = root.descendant_for_byte_range(start, end)?;
    if node.start_byte() != start || node.end_byte() != end {
        return None;
    }
    if !EXPRESSION_KINDS.contains(&node.kind()) {
        return None;
    }
    let statement = enclosing(node)?;
    Some(ExtractSpans {
        expr: ByteRange {
            start_byte: start as u32,
            end_byte: end as u32,
        },
        statement: ByteRange {
            start_byte: statement.start_byte() as u32,
            end_byte: statement.end_byte() as u32,
        },
    })
}

fn enclosing(node: Node<'_>) -> Option<Node<'_>> {
    let mut current = node;
    while let Some(parent) = current.parent() {
        if BODY_KINDS.contains(&parent.kind()) {
            return Some(current);
        }
        current = parent;
    }
    None
}

pub(super) fn trimmed(text: &str, range: ByteRange) -> Option<(usize, usize)> {
    let start = (range.start_byte as usize).min(text.len());
    let end = (range.end_byte as usize).min(text.len());
    let slice = text.get(start..end)?;
    let lead = slice.len() - slice.trim_start().len();
    let trail = slice.len() - slice.trim_end().len();
    let from = start + lead;
    let to = end - trail;
    (from < to).then_some((from, to))
}
