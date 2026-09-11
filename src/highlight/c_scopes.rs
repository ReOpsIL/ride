use tree_sitter::Node;

use crate::ffi::{ItemKind, OutlineItem};

use super::c_names::{function_name, node_text, plain_name};
use super::types::TypeTable;

const TRANSPARENT: &[&str] = &[
    "template_declaration",
    "linkage_specification",
    "declaration_list",
    "preproc_if",
    "preproc_ifdef",
    "preproc_else",
    "preproc_elif",
    "preproc_elifdef",
];

pub fn namespace(table: &mut TypeTable, node: Node<'_>, text: &str) {
    let Some(body) = node.child_by_field_name("body") else {
        return;
    };
    let path = namespace_path(node, text);
    if path.is_empty() {
        return;
    }
    let mut items = Vec::new();
    scope_items(body, text, &mut items);
    table.add_scope(path, items);
}

pub fn namespace_alias(table: &mut TypeTable, node: Node<'_>, text: &str) {
    let mut cursor = node.walk();
    let mut names = node
        .named_children(&mut cursor)
        .filter(|c| !c.kind().starts_with("comment"));
    if let (Some(alias), Some(target)) = (names.next(), names.next()) {
        table.add_alias(node_text(alias, text), node_text(target, text));
    }
}

fn namespace_path(node: Node<'_>, text: &str) -> String {
    let mut parts: Vec<String> = Vec::new();
    let mut current = Some(node);
    while let Some(n) = current {
        if n.kind() == "namespace_definition"
            && !is_inline(n)
            && let Some(name) = n.child_by_field_name("name")
        {
            parts.push(node_text(name, text));
        }
        current = n.parent();
    }
    parts.reverse();
    parts.join("::")
}

fn is_inline(node: Node<'_>) -> bool {
    let mut cursor = node.walk();
    node.children(&mut cursor).any(|c| c.kind() == "inline")
}

fn scope_items(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        match child.kind() {
            "function_definition" => function(child, text, out),
            "declaration" => declaration(child, text, out),
            "class_specifier" => named(child, ItemKind::Class, text, out),
            "struct_specifier" => named(child, ItemKind::Struct, text, out),
            "union_specifier" => named(child, ItemKind::Union, text, out),
            "enum_specifier" => named(child, ItemKind::Enum, text, out),
            "alias_declaration" => named(child, ItemKind::Type, text, out),
            "concept_definition" => named(child, ItemKind::Trait, text, out),
            "type_definition" => typedef(child, text, out),
            "namespace_definition" if is_inline(child) => nested(child, text, out),
            "namespace_definition" => {
                if child.child_by_field_name("name").is_some() {
                    named(child, ItemKind::Namespace, text, out);
                } else {
                    nested(child, text, out);
                }
            }
            k if TRANSPARENT.contains(&k) => scope_items(child, text, out),
            _ => {}
        }
    }
}

fn nested(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    if let Some(body) = node.child_by_field_name("body") {
        scope_items(body, text, out);
    }
}

fn function(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    if let Some(declarator) = node.child_by_field_name("declarator")
        && let Some((name, _)) = function_name(declarator, text)
    {
        push(node, name, ItemKind::Fn, text, out);
    }
}

fn declaration(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    if let Some(ty) = node.child_by_field_name("type")
        && ty.child_by_field_name("body").is_some()
    {
        scope_items(node, text, out);
    }
    let mut cursor = node.walk();
    for declarator in node.children_by_field_name("declarator", &mut cursor) {
        if let Some((name, _)) = function_name(declarator, text) {
            push(node, name, ItemKind::Fn, text, out);
        } else if let Some(name) = plain_name(declarator, text) {
            push(node, name, ItemKind::Static, text, out);
        }
    }
}

fn typedef(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    let mut cursor = node.walk();
    for declarator in node.children_by_field_name("declarator", &mut cursor) {
        if let Some(name) = plain_name(declarator, text) {
            push(node, name, ItemKind::Type, text, out);
        }
    }
}

fn named(node: Node<'_>, kind: ItemKind, text: &str, out: &mut Vec<OutlineItem>) {
    if let Some(name) = node.child_by_field_name("name") {
        push(node, node_text(name, text), kind, text, out);
    }
}

fn push(node: Node<'_>, name: String, kind: ItemKind, text: &str, out: &mut Vec<OutlineItem>) {
    if !name.is_empty() {
        let name_start_byte = super::symbol::name_start_byte(node, &name, text);
        let mut item =
            OutlineItem::new(name, kind, node.start_byte() as u32, node.end_byte() as u32);
        item.name_start_byte = name_start_byte;
        out.push(item);
    }
}
