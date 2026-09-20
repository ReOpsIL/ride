use tree_sitter::Node;

use crate::ffi::ByteRange;

use super::spans::trimmed;

const ITEM_KINDS: [&str; 10] = [
    "function_item",
    "impl_item",
    "struct_item",
    "enum_item",
    "mod_item",
    "trait_item",
    "function_definition",
    "class_specifier",
    "struct_specifier",
    "namespace_definition",
];

const CONTAINER_KINDS: [&str; 3] = ["source_file", "translation_unit", "declaration_list"];

const NUMERIC_KINDS: [&str; 3] = ["integer_literal", "float_literal", "number_literal"];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LiteralKind {
    Int,
    Float,
    Str,
    Char,
    Bool,
}

pub struct ConstantSpans {
    pub literal: ByteRange,
    pub anchor: ByteRange,
    pub kind: LiteralKind,
}

pub fn constant_spans(root: Node<'_>, text: &str, range: ByteRange) -> Option<ConstantSpans> {
    let (start, end) = trimmed(text, range)?;
    let node = root.descendant_for_byte_range(start, end)?;
    if node.start_byte() != start || node.end_byte() != end {
        return None;
    }
    let kind = kind_of(node, text)?;
    let anchor = anchor(node)?;
    Some(ConstantSpans {
        literal: ByteRange {
            start_byte: start as u32,
            end_byte: end as u32,
        },
        anchor: ByteRange {
            start_byte: anchor.start_byte() as u32,
            end_byte: anchor.end_byte() as u32,
        },
        kind,
    })
}

fn kind_of(node: Node<'_>, text: &str) -> Option<LiteralKind> {
    match node.kind() {
        "integer_literal" => Some(LiteralKind::Int),
        "float_literal" => Some(LiteralKind::Float),
        "string_literal" | "raw_string_literal" => Some(LiteralKind::Str),
        "char_literal" => Some(LiteralKind::Char),
        "boolean_literal" | "true" | "false" => Some(LiteralKind::Bool),
        "number_literal" => node.utf8_text(text.as_bytes()).ok().map(number_kind),
        "unary_expression" => numeric_child(node, text),
        _ => None,
    }
}

fn numeric_child(node: Node<'_>, text: &str) -> Option<LiteralKind> {
    let child = node.named_child(0)?;
    NUMERIC_KINDS
        .contains(&child.kind())
        .then(|| kind_of(child, text))
        .flatten()
}

fn number_kind(literal: &str) -> LiteralKind {
    let lower = literal.to_ascii_lowercase();
    let hex = lower.starts_with("0x");
    let exponent = if hex {
        lower.contains('p')
    } else {
        lower.contains('e')
    };
    let suffixed = !hex && (lower.ends_with('f') || lower.ends_with('l') && lower.contains('.'));
    if lower.contains('.') || exponent || suffixed {
        LiteralKind::Float
    } else {
        LiteralKind::Int
    }
}

fn anchor(node: Node<'_>) -> Option<Node<'_>> {
    let mut current = node;
    while let Some(parent) = current.parent() {
        if ITEM_KINDS.contains(&current.kind()) && CONTAINER_KINDS.contains(&parent.kind()) {
            return Some(current);
        }
        current = parent;
    }
    None
}
