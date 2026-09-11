use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};

use super::rust_type_names::type_name;
use super::symbol::node_text;
use super::types::TypeTable;
use super::walk::each_node;

pub fn build(tree: &Tree, text: &str) -> TypeTable {
    let mut table = TypeTable::default();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        "struct_item" | "union_item" => register(&mut table, node, text, field_kind),
        "enum_item" => register(&mut table, node, text, variant_kind),
        "trait_item" | "impl_item" => register(&mut table, node, text, assoc_kind),
        "type_item" => alias(&mut table, node, text),
        _ => {}
    });
    table
}

pub fn field_type(tree: &Tree, text: &str, owner_name: &str, field: &str) -> Option<String> {
    let mut found = None;
    each_node(tree.root_node(), &mut |node| {
        if found.is_some()
            || !matches!(node.kind(), "struct_item" | "union_item")
            || owner(node, text).as_deref() != Some(owner_name)
        {
            return;
        }
        found = declared_field(node, text, field);
    });
    found
}

fn owner(node: Node<'_>, text: &str) -> Option<String> {
    let field = if node.kind() == "impl_item" {
        "type"
    } else {
        "name"
    };
    type_name(node.child_by_field_name(field)?, text)
}

fn register(table: &mut TypeTable, node: Node<'_>, text: &str, kind: fn(&str) -> Option<ItemKind>) {
    let Some(name) = owner(node, text) else {
        return;
    };
    let Some(body) = node.child_by_field_name("body") else {
        return;
    };
    let mut cursor = body.walk();
    let items = body
        .named_children(&mut cursor)
        .filter_map(|child| {
            let kind = kind(child.kind())?;
            let name = child.child_by_field_name("name")?;
            let mut item = OutlineItem::new(
                node_text(name, text),
                kind,
                child.start_byte() as u32,
                child.end_byte() as u32,
            );
            item.name_start_byte = name.start_byte() as u32;
            item.signature = head_text(child, text);
            let detail = child
                .child_by_field_name("type")
                .map(|t| node_text(t, text))
                .unwrap_or_default();
            Some((item, detail))
        })
        .collect::<Vec<(OutlineItem, String)>>();
    let details: Vec<(String, String)> = items
        .iter()
        .filter(|(_, d)| !d.is_empty())
        .map(|(i, d)| (i.name.clone(), d.clone()))
        .collect();
    let types: Vec<(String, String)> = items
        .iter()
        .filter_map(|(i, d)| type_name_of(d).map(|t| (i.name.clone(), t)))
        .collect();
    table.add_members(name.clone(), items.into_iter().map(|(i, _)| i).collect());
    table.add_member_types(name.clone(), types);
    table.add_member_details(name, details);
}

fn type_name_of(detail: &str) -> Option<String> {
    let mut rest = detail.trim();
    loop {
        let before = rest;
        rest = rest.trim_start_matches(['&', '*']).trim_start();
        for prefix in ["mut ", "const ", "dyn ", "impl "] {
            rest = rest.strip_prefix(prefix).unwrap_or(rest).trim_start();
        }
        if rest.starts_with('\'') {
            rest = rest.trim_start_matches(|c: char| c == '\'' || c.is_alphanumeric() || c == '_');
            rest = rest.trim_start();
        }
        if rest == before {
            break;
        }
    }
    let end = rest
        .find(|c: char| !(c.is_alphanumeric() || c == '_' || c == ':'))
        .unwrap_or(rest.len());
    let path = &rest[..end];
    let name = path.rsplit("::").next().unwrap_or(path);
    (!name.is_empty()).then(|| name.to_string())
}

fn head_text(node: Node<'_>, text: &str) -> String {
    let raw = node_text(node, text);
    let end = raw.find(['{', ';', '=']).unwrap_or(raw.len());
    let head: String = raw[..end].split_whitespace().collect::<Vec<_>>().join(" ");
    head.chars().take(160).collect()
}

fn field_kind(kind: &str) -> Option<ItemKind> {
    (kind == "field_declaration").then_some(ItemKind::Field)
}

fn variant_kind(kind: &str) -> Option<ItemKind> {
    (kind == "enum_variant").then_some(ItemKind::Variant)
}

fn assoc_kind(kind: &str) -> Option<ItemKind> {
    match kind {
        "function_item" | "function_signature_item" => Some(ItemKind::Method),
        "const_item" => Some(ItemKind::Const),
        "type_item" | "associated_type" => Some(ItemKind::Type),
        _ => None,
    }
}

fn alias(table: &mut TypeTable, node: Node<'_>, text: &str) {
    let associated = node
        .parent()
        .and_then(|p| p.parent())
        .is_some_and(|g| matches!(g.kind(), "impl_item" | "trait_item"));
    if associated {
        return;
    }
    if let Some(name) = node.child_by_field_name("name")
        && let Some(ty) = node.child_by_field_name("type")
        && let Some(target) = type_name(ty, text)
    {
        table.add_alias(node_text(name, text), target);
    }
}

fn declared_field(node: Node<'_>, text: &str, field: &str) -> Option<String> {
    let body = node.child_by_field_name("body")?;
    let mut cursor = body.walk();
    body.named_children(&mut cursor)
        .filter(|c| c.kind() == "field_declaration")
        .find(|c| {
            c.child_by_field_name("name")
                .is_some_and(|n| node_text(n, text) == field)
        })
        .and_then(|c| c.child_by_field_name("type"))
        .and_then(|t| type_name(t, text))
}
