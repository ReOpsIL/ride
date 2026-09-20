use tree_sitter::Node;

use crate::ffi::ByteRange;
use crate::highlight::walk::each_node;

const SCOPE_KINDS: [&str; 4] = [
    "function_item",
    "closure_expression",
    "function_definition",
    "lambda_expression",
];

const SIDE_EFFECT_KINDS: [&str; 3] = [
    "call_expression",
    "method_call_expression",
    "macro_invocation",
];

const ASSIGN_KINDS: [&str; 2] = ["assignment_expression", "compound_assignment_expr"];

const GROUP_KINDS: [&str; 2] = ["binary_expression", "unary_expression"];

pub struct InlineSpans {
    pub name: ByteRange,
    pub statement: ByteRange,
    pub init: ByteRange,
    pub parenthesize: bool,
}

enum Declared<'a> {
    Refuse,
    Pair(Node<'a>, Node<'a>),
}

pub fn inline_spans(root: Node<'_>, text: &str, byte: u32) -> Option<InlineSpans> {
    let ident = ident_at(root, byte)?;
    let name = ident.utf8_text(text.as_bytes()).ok()?;
    if name.is_empty() {
        return None;
    }
    let scope = enclosing_scope(ident)?;
    if assigned(scope, text, name) {
        return None;
    }
    let (statement, declared, value) = declaration(scope, text, name)?;
    if has_side_effects(value) {
        return None;
    }
    Some(InlineSpans {
        name: range_of(declared),
        statement: range_of(statement),
        init: range_of(value),
        parenthesize: GROUP_KINDS.contains(&value.kind()),
    })
}

fn range_of(node: Node<'_>) -> ByteRange {
    ByteRange {
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
    }
}

fn ident_at<'a>(root: Node<'a>, byte: u32) -> Option<Node<'a>> {
    let byte = byte as usize;
    exact(root, byte).or_else(|| byte.checked_sub(1).and_then(|b| exact(root, b)))
}

fn exact<'a>(root: Node<'a>, byte: usize) -> Option<Node<'a>> {
    let node = root.descendant_for_byte_range(byte, byte)?;
    (node.kind() == "identifier").then_some(node)
}

fn enclosing_scope(node: Node<'_>) -> Option<Node<'_>> {
    let mut current = node.parent();
    while let Some(n) = current {
        if SCOPE_KINDS.contains(&n.kind()) {
            return Some(n);
        }
        current = n.parent();
    }
    None
}

fn declaration<'a>(
    scope: Node<'a>,
    text: &str,
    name: &str,
) -> Option<(Node<'a>, Node<'a>, Node<'a>)> {
    let mut found = None;
    let mut refused = false;
    each_node(scope, &mut |node| {
        if refused {
            return;
        }
        match declared_in(node, text, name) {
            Some(Declared::Refuse) => refused = true,
            Some(Declared::Pair(declared, value)) if found.is_none() => {
                found = Some((node, declared, value));
            }
            Some(Declared::Pair(_, _)) => refused = true,
            None => {}
        }
    });
    if refused { None } else { found }
}

fn declared_in<'a>(node: Node<'a>, text: &str, name: &str) -> Option<Declared<'a>> {
    match node.kind() {
        "let_declaration" => rust_declared(node, text, name),
        "declaration" => c_declared(node, text, name),
        _ => None,
    }
}

fn rust_declared<'a>(node: Node<'a>, text: &str, name: &str) -> Option<Declared<'a>> {
    let pattern = node.child_by_field_name("pattern")?;
    let inner = if pattern.kind() == "mut_pattern" {
        pattern.named_child(0)?
    } else {
        pattern
    };
    if inner.kind() != "identifier" || !is_named(inner, text, name) {
        return None;
    }
    if pattern.kind() == "mut_pattern" || mutable(node) {
        return Some(Declared::Refuse);
    }
    match node.child_by_field_name("value") {
        Some(value) => Some(Declared::Pair(inner, value)),
        None => Some(Declared::Refuse),
    }
}

fn mutable(node: Node<'_>) -> bool {
    let mut cursor = node.walk();
    node.children(&mut cursor)
        .any(|c| c.kind() == "mutable_specifier")
}

fn c_declared<'a>(node: Node<'a>, text: &str, name: &str) -> Option<Declared<'a>> {
    let mut cursor = node.walk();
    let declarators: Vec<Node<'a>> = node
        .named_children(&mut cursor)
        .filter(|c| c.kind() == "init_declarator")
        .collect();
    let first = declarators.first()?;
    let declarator = first.child_by_field_name("declarator")?;
    if declarator.kind() != "identifier" || !is_named(declarator, text, name) {
        return None;
    }
    if declarators.len() != 1 {
        return Some(Declared::Refuse);
    }
    match first.child_by_field_name("value") {
        Some(value) => Some(Declared::Pair(declarator, value)),
        None => Some(Declared::Refuse),
    }
}

fn is_named(node: Node<'_>, text: &str, name: &str) -> bool {
    node.utf8_text(text.as_bytes()) == Ok(name)
}

fn assigned(scope: Node<'_>, text: &str, name: &str) -> bool {
    let mut hit = false;
    each_node(scope, &mut |node| {
        if hit || !ASSIGN_KINDS.contains(&node.kind()) {
            return;
        }
        if let Some(left) = node.child_by_field_name("left")
            && left.kind() == "identifier"
            && is_named(left, text, name)
        {
            hit = true;
        }
    });
    hit
}

fn has_side_effects(value: Node<'_>) -> bool {
    let mut hit = false;
    each_node(value, &mut |node| {
        if SIDE_EFFECT_KINDS.contains(&node.kind()) {
            hit = true;
        }
    });
    hit
}
