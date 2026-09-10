use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};

use super::c_docs;
use super::c_locals::declared_type;
use super::c_names::{SPECIFIERS, function_name, node_text, plain_name, type_name};
use super::types::{Member, TypeTable};
use super::walk::each_node;

pub fn build(tree: &Tree, text: &str) -> TypeTable {
    let mut table = TypeTable::default();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        k if SPECIFIERS.contains(&k) => specifier(&mut table, node, text, None),
        "type_definition" => typedef(&mut table, node, text),
        "alias_declaration" => alias(&mut table, node, text),
        _ => {}
    });
    table
}

fn specifier(table: &mut TypeTable, node: Node<'_>, text: &str, fallback: Option<&str>) {
    let Some(body) = node.child_by_field_name("body") else {
        return;
    };
    let name = node
        .child_by_field_name("name")
        .map(|n| node_text(n, text))
        .or_else(|| fallback.map(str::to_string));
    let Some(name) = name else {
        return;
    };
    let mut items = Vec::new();
    members(body, text, &mut items);
    table.add_members(name.clone(), items);
    table.add_bases(name, bases(node, text));
}

fn typedef(table: &mut TypeTable, node: Node<'_>, text: &str) {
    let Some(ty) = node.child_by_field_name("type") else {
        return;
    };
    let mut cursor = node.walk();
    for declarator in node.children_by_field_name("declarator", &mut cursor) {
        let Some(alias) = plain_name(declarator, text) else {
            continue;
        };
        match type_name(ty, text) {
            Some(target) => table.add_alias(alias, target),
            None if SPECIFIERS.contains(&ty.kind()) => specifier(table, ty, text, Some(&alias)),
            None => {}
        }
    }
}

fn alias(table: &mut TypeTable, node: Node<'_>, text: &str) {
    if let Some(name) = node.child_by_field_name("name")
        && let Some(ty) = node.child_by_field_name("type")
        && let Some(target) = type_name(ty, text)
    {
        table.add_alias(node_text(name, text), target);
    }
}

fn bases(node: Node<'_>, text: &str) -> Vec<String> {
    let mut cursor = node.walk();
    let Some(clause) = node
        .named_children(&mut cursor)
        .find(|c| c.kind() == "base_class_clause")
    else {
        return Vec::new();
    };
    let mut cursor = clause.walk();
    clause
        .named_children(&mut cursor)
        .filter_map(|c| type_name(c, text))
        .collect()
}

fn members(body: Node<'_>, text: &str, out: &mut Vec<Member>) {
    let mut cursor = body.walk();
    for child in body.named_children(&mut cursor) {
        match child.kind() {
            "field_declaration" | "declaration" => declarators(child, text, out),
            "function_definition" => {
                if let Some(d) = child.child_by_field_name("declarator")
                    && let Some((name, _)) = function_name(d, text)
                {
                    push(child, name, ItemKind::Method, String::new(), text, out);
                }
            }
            "template_declaration" => members(child, text, out),
            "alias_declaration" => named(child, ItemKind::Type, text, out),
            "enum_specifier" => named(child, ItemKind::Enum, text, out),
            "class_specifier" => named(child, ItemKind::Class, text, out),
            "struct_specifier" => named(child, ItemKind::Struct, text, out),
            "union_specifier" => named(child, ItemKind::Union, text, out),
            _ => {}
        }
    }
}

fn declarators(node: Node<'_>, text: &str, out: &mut Vec<Member>) {
    let mut cursor = node.walk();
    for declarator in node.children_by_field_name("declarator", &mut cursor) {
        if let Some((name, _)) = function_name(declarator, text) {
            push(node, name, ItemKind::Method, String::new(), text, out);
        } else if let Some(name) = plain_name(declarator, text) {
            let detail = declared_type(node, declarator, text).unwrap_or_default();
            push(node, name, ItemKind::Field, detail, text, out);
        }
    }
}

fn named(node: Node<'_>, kind: ItemKind, text: &str, out: &mut Vec<Member>) {
    if let Some(name) = node.child_by_field_name("name") {
        push(node, node_text(name, text), kind, String::new(), text, out);
    }
}

fn push(
    node: Node<'_>,
    name: String,
    kind: ItemKind,
    detail: String,
    text: &str,
    out: &mut Vec<Member>,
) {
    if name.is_empty() {
        return;
    }
    let item = OutlineItem {
        name,
        kind,
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
        signature: c_docs::signature(node, text),
        doc: c_docs::doc(node, text),
    };
    out.push(Member::new(item, detail));
}
