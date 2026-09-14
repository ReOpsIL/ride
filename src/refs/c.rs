use tree_sitter::{Node, Parser};

use crate::ffi::{ItemKind, OutlineItem};
use crate::highlight::Lang;

use super::record::{RefExtractor, RefKind, RefRecord};

pub struct CExtractor;

impl RefExtractor for CExtractor {
    fn extract(&self, lang: Lang, text: &str) -> Vec<RefRecord> {
        extract(lang, text).unwrap_or_default()
    }
}

struct Ctx<'a> {
    text: &'a str,
    outline: &'a [OutlineItem],
    out: Vec<RefRecord>,
}

fn extract(lang: Lang, text: &str) -> Option<Vec<RefRecord>> {
    let grammar = lang.grammar()?;
    let mut parser = Parser::new();
    parser.set_language(&grammar.language).ok()?;
    let tree = parser.parse(text, None)?;
    let outline = (grammar.outline)(&tree, text);
    let mut ctx = Ctx {
        text,
        outline: &outline,
        out: Vec::new(),
    };
    walk(tree.root_node(), &mut ctx);
    Some(ctx.out)
}

fn walk(node: Node<'_>, ctx: &mut Ctx<'_>) {
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit(child, ctx);
    }
}

fn visit(node: Node<'_>, ctx: &mut Ctx<'_>) {
    match node.kind() {
        "preproc_include" => {
            emit_include(node, ctx);
            return;
        }
        "type_identifier" => push(node, RefKind::TypeMention, ctx),
        "field_identifier" => {
            if is_callee(node) {
                push(node, RefKind::Call, ctx);
            } else if node
                .parent()
                .is_some_and(|p| p.kind() == "field_expression")
            {
                push(node, RefKind::FieldAccess, ctx);
            }
        }
        "identifier" => {
            let kind = if is_callee(node) {
                RefKind::Call
            } else {
                RefKind::Ident
            };
            push(node, kind, ctx);
        }
        _ => {}
    }
    walk(node, ctx);
}

fn is_callee(node: Node<'_>) -> bool {
    let mut cur = node;
    while let Some(parent) = cur.parent() {
        match parent.kind() {
            "call_expression" => {
                return parent
                    .child_by_field_name("function")
                    .is_some_and(|f| f.id() == cur.id());
            }
            "field_expression" => {
                if !field_is(parent, "field", cur) {
                    return false;
                }
                cur = parent;
            }
            "qualified_identifier" | "template_function" | "template_method" => {
                if !field_is(parent, "name", cur) {
                    return false;
                }
                cur = parent;
            }
            _ => return false,
        }
    }
    false
}

fn field_is(parent: Node<'_>, field: &str, cur: Node<'_>) -> bool {
    parent
        .child_by_field_name(field)
        .is_some_and(|c| c.id() == cur.id())
}

fn emit_include(node: Node<'_>, ctx: &mut Ctx<'_>) {
    let Some(path) = node.child_by_field_name("path") else {
        return;
    };
    let raw = node_text(path, ctx.text);
    let name = raw
        .trim()
        .trim_matches('"')
        .trim_start_matches('<')
        .trim_end_matches('>')
        .to_string();
    record(
        ctx,
        name,
        RefKind::Include,
        path.start_byte() as u32,
        path.end_byte() as u32,
    );
}

fn push(node: Node<'_>, kind: RefKind, ctx: &mut Ctx<'_>) {
    let name = node_text(node, ctx.text);
    record(
        ctx,
        name,
        kind,
        node.start_byte() as u32,
        node.end_byte() as u32,
    );
}

fn record(ctx: &mut Ctx<'_>, name: String, kind: RefKind, start: u32, end: u32) {
    if name.is_empty() {
        return;
    }
    let (enclosing_item, enclosing_kind) = enclosing(ctx.outline, start);
    ctx.out.push(RefRecord {
        name,
        kind,
        path: String::new(),
        line: line_at(ctx.text, start as usize),
        byte_start: start,
        byte_end: end,
        enclosing_item,
        enclosing_kind,
    });
}

fn enclosing(outline: &[OutlineItem], byte: u32) -> (String, ItemKind) {
    let mut best: Option<&OutlineItem> = None;
    for item in outline {
        if byte < item.start_byte || byte >= item.end_byte {
            continue;
        }
        if best.is_none_or(|b| item.start_byte > b.start_byte) {
            best = Some(item);
        }
    }
    match best {
        Some(item) => (item.name.clone(), item.kind),
        None => (String::new(), ItemKind::Mod),
    }
}

fn line_at(text: &str, byte: usize) -> u32 {
    let end = byte.min(text.len());
    text[..end].bytes().filter(|&c| c == b'\n').count() as u32 + 1
}

fn node_text(node: Node<'_>, text: &str) -> String {
    node.utf8_text(text.as_bytes())
        .unwrap_or_default()
        .to_string()
}
