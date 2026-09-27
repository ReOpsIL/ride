use tree_sitter::Node;

use crate::highlight::walk::each_node;

pub struct Declaration<'t> {
    pub statement: Node<'t>,
    pub name: Node<'t>,
    pub value: Node<'t>,
}

enum Declared<'t> {
    Refuse,
    Pair(Node<'t>, Node<'t>),
}

pub fn declaration<'t>(scope: Node<'t>, text: &str, name: &str) -> Option<Declaration<'t>> {
    let mut found = None;
    let mut refused = false;
    each_node(scope, &mut |node| {
        if refused {
            return;
        }
        match declared_in(node, text, name) {
            Some(Declared::Pair(declared, value)) if found.is_none() => {
                found = Some(Declaration {
                    statement: node,
                    name: declared,
                    value,
                });
            }
            Some(_) => refused = true,
            None => {}
        }
    });
    if refused { None } else { found }
}

pub fn is_named(node: Node<'_>, text: &str, name: &str) -> bool {
    node.utf8_text(text.as_bytes()) == Ok(name)
}

fn declared_in<'t>(node: Node<'t>, text: &str, name: &str) -> Option<Declared<'t>> {
    match node.kind() {
        "let_declaration" => rust_declared(node, text, name),
        "declaration" => c_declared(node, text, name),
        _ => None,
    }
}

fn rust_declared<'t>(node: Node<'t>, text: &str, name: &str) -> Option<Declared<'t>> {
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

fn c_declared<'t>(node: Node<'t>, text: &str, name: &str) -> Option<Declared<'t>> {
    let mut cursor = node.walk();
    let declarators: Vec<Node<'t>> = node
        .children_by_field_name("declarator", &mut cursor)
        .collect();
    let target = declarators
        .iter()
        .copied()
        .find(|d| declared_ident(*d).is_some_and(|i| is_named(i, text, name)))?;
    if declarators.len() != 1 {
        return Some(Declared::Refuse);
    }
    let ident = declared_ident(target)?;
    match target.child_by_field_name("value") {
        Some(value) if target.kind() == "init_declarator" => Some(Declared::Pair(ident, value)),
        _ => Some(Declared::Refuse),
    }
}

fn declared_ident(declarator: Node<'_>) -> Option<Node<'_>> {
    match declarator.kind() {
        "identifier" => Some(declarator),
        "init_declarator" => declarator
            .child_by_field_name("declarator")
            .filter(|d| d.kind() == "identifier"),
        _ => None,
    }
}
