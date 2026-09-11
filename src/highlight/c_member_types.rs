use tree_sitter::Node;

use crate::ffi::{ItemKind, OutlineItem};

use super::c_names::{function_name, node_text, plain_name, type_name};
use super::types::TypeTable;

const TYPED: &[&str] = &["field_declaration", "declaration", "function_definition"];

pub fn collect_member_types(body: Node<'_>, text: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    let mut cursor = body.walk();
    for child in body.named_children(&mut cursor) {
        match child.kind() {
            k if TYPED.contains(&k) => out.extend(typed_declarators(child, text)),
            "template_declaration" => out.extend(collect_member_types(child, text)),
            _ => {}
        }
    }
    out
}

pub fn collect_member_details(body: Node<'_>, text: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    let mut cursor = body.walk();
    for child in body.named_children(&mut cursor) {
        match child.kind() {
            k if TYPED.contains(&k) => out.extend(detailed_declarators(child, text)),
            "template_declaration" => out.extend(collect_member_details(child, text)),
            _ => {}
        }
    }
    out
}

fn detailed_declarators(node: Node<'_>, text: &str) -> Vec<(String, String)> {
    let mut cursor = node.walk();
    node.children_by_field_name("declarator", &mut cursor)
        .filter_map(|d| {
            let name = function_name(d, text)
                .map(|(name, _)| name)
                .or_else(|| plain_name(d, text))?;
            let detail = super::c_locals::declared_type(node, d, text)?;
            Some((name, detail))
        })
        .collect()
}

pub fn typed_declarators(node: Node<'_>, text: &str) -> Vec<(String, String)> {
    let Some(ty) = node
        .child_by_field_name("type")
        .and_then(|t| type_name(t, text))
    else {
        return Vec::new();
    };
    let mut cursor = node.walk();
    node.children_by_field_name("declarator", &mut cursor)
        .filter_map(|d| {
            function_name(d, text)
                .map(|(name, _)| name)
                .or_else(|| plain_name(d, text))
        })
        .map(|name| (name, ty.clone()))
        .collect()
}

pub fn free_function(table: &mut TypeTable, node: Node<'_>, text: &str) {
    if node
        .parent()
        .is_some_and(|p| p.kind() == "field_declaration_list")
    {
        return;
    }
    let Some(ty) = node
        .child_by_field_name("type")
        .and_then(|t| type_name(t, text))
    else {
        return;
    };
    let mut cursor = node.walk();
    for declarator in node.children_by_field_name("declarator", &mut cursor) {
        if let Some((name, _)) = function_name(declarator, text) {
            table.add_function(name, ty.clone());
        }
    }
}

pub fn enumerators(table: &mut TypeTable, node: Node<'_>, text: &str) {
    let (Some(name), Some(body)) = (
        node.child_by_field_name("name"),
        node.child_by_field_name("body"),
    ) else {
        return;
    };
    let mut cursor = body.walk();
    let items: Vec<OutlineItem> = body
        .named_children(&mut cursor)
        .filter(|c| c.kind() == "enumerator")
        .filter_map(|c| c.child_by_field_name("name").map(|n| (c, n)))
        .map(|(c, n)| {
            let mut item = OutlineItem::new(
                node_text(n, text),
                ItemKind::Variant,
                c.start_byte() as u32,
                c.end_byte() as u32,
            );
            item.name_start_byte = n.start_byte() as u32;
            item
        })
        .collect();
    table.add_members(node_text(name, text), items);
}
