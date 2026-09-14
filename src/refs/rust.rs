use tree_sitter::{Language, Node, Parser, Tree};

use crate::ffi::{ItemKind, OutlineItem};
use crate::highlight::Lang;
use crate::highlight::rust_outline;
use crate::highlight::symbol::node_text;

use super::record::{RefExtractor, RefKind, RefRecord};

pub struct RustExtractor;

impl RefExtractor for RustExtractor {
    fn extract(&self, _lang: Lang, text: &str) -> Vec<RefRecord> {
        extract(text)
    }
}

fn extract(text: &str) -> Vec<RefRecord> {
    let Some(tree) = parse(text) else {
        return Vec::new();
    };
    let outline = rust_outline::from_source(text).unwrap_or_default();
    let mut out = Vec::new();
    walk(tree.root_node(), text, &outline, &mut out);
    out
}

fn parse(text: &str) -> Option<Tree> {
    let mut parser = Parser::new();
    parser
        .set_language(&Language::new(tree_sitter_rust::LANGUAGE))
        .ok()?;
    parser.parse(text, None)
}

fn walk(node: Node<'_>, text: &str, outline: &[OutlineItem], out: &mut Vec<RefRecord>) {
    if let Some((leaf, kind)) = classify(node, text) {
        out.push(record(leaf, kind, text, outline));
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        walk(child, text, outline, out);
    }
}

fn classify<'a>(node: Node<'a>, text: &str) -> Option<(Node<'a>, RefKind)> {
    match node.kind() {
        "type_identifier" => Some((node, RefKind::TypeMention)),
        "field_identifier" => field_kind(node).map(|k| (node, k)),
        "identifier" => Some((node, identifier_kind(node, text))),
        _ => None,
    }
}

fn field_kind(node: Node<'_>) -> Option<RefKind> {
    let parent = node.parent()?;
    if parent.kind() != "field_expression" || !is_field(parent, "field", node) {
        return None;
    }
    match parent.parent() {
        Some(gp) if gp.kind() == "call_expression" && is_field(gp, "function", parent) => {
            Some(RefKind::Call)
        }
        _ => Some(RefKind::FieldAccess),
    }
}

fn identifier_kind(node: Node<'_>, text: &str) -> RefKind {
    if in_use(node) {
        return RefKind::UsePath;
    }
    let Some(parent) = node.parent() else {
        return RefKind::Ident;
    };
    match parent.kind() {
        "call_expression" if is_field(parent, "function", node) => RefKind::Call,
        "scoped_identifier" => scoped_kind(parent, node, text),
        _ => RefKind::Ident,
    }
}

fn scoped_kind(parent: Node<'_>, node: Node<'_>, text: &str) -> RefKind {
    if is_field(parent, "name", node) {
        if let Some(gp) = parent.parent()
            && gp.kind() == "call_expression"
            && is_field(gp, "function", parent)
        {
            return RefKind::Call;
        }
        return RefKind::Ident;
    }
    if is_field(parent, "path", node) && starts_upper(node, text) {
        return RefKind::TypeMention;
    }
    RefKind::Ident
}

fn in_use(node: Node<'_>) -> bool {
    let mut cur = node.parent();
    while let Some(n) = cur {
        match n.kind() {
            "use_declaration" => return true,
            "source_file" | "block" | "function_item" => return false,
            _ => cur = n.parent(),
        }
    }
    false
}

fn is_field(parent: Node<'_>, name: &str, node: Node<'_>) -> bool {
    parent.child_by_field_name(name).map(|c| c.id()) == Some(node.id())
}

fn starts_upper(node: Node<'_>, text: &str) -> bool {
    node_text(node, text)
        .chars()
        .next()
        .is_some_and(char::is_uppercase)
}

fn record(node: Node<'_>, kind: RefKind, text: &str, outline: &[OutlineItem]) -> RefRecord {
    let byte_start = node.start_byte() as u32;
    let byte_end = node.end_byte() as u32;
    let (enclosing_item, enclosing_kind) = enclosing(outline, byte_start);
    RefRecord {
        name: node_text(node, text),
        kind,
        path: String::new(),
        line: node.start_position().row as u32 + 1,
        byte_start,
        byte_end,
        enclosing_item,
        enclosing_kind,
    }
}

fn enclosing(outline: &[OutlineItem], byte: u32) -> (String, ItemKind) {
    outline
        .iter()
        .filter(|o| o.start_byte <= byte && byte < o.end_byte)
        .min_by_key(|o| o.end_byte - o.start_byte)
        .map(|o| (o.name.clone(), o.kind))
        .unwrap_or_else(|| (String::new(), ItemKind::Mod))
}
