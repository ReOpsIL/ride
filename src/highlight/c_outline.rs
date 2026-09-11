use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};

use super::c_docs;
use super::c_names::{function_name, node_text, plain_name};

const TRANSPARENT: [&str; 10] = [
    "template_declaration",
    "linkage_specification",
    "preproc_if",
    "preproc_ifdef",
    "preproc_else",
    "preproc_elif",
    "preproc_elifdef",
    "declaration_list",
    "field_declaration_list",
    "translation_unit",
];

pub fn outline(tree: &Tree, text: &str) -> Vec<OutlineItem> {
    let mut out = Vec::new();
    scope(tree.root_node(), text, false, &mut out);
    out
}

fn scope(node: Node<'_>, text: &str, in_type: bool, out: &mut Vec<OutlineItem>) {
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        item(child, text, in_type, out);
    }
}

fn item(node: Node<'_>, text: &str, in_type: bool, out: &mut Vec<OutlineItem>) {
    match node.kind() {
        "function_definition" => function(node, text, in_type, out),
        "declaration" | "field_declaration" => declaration(node, text, in_type, out),
        "struct_specifier" | "class_specifier" | "union_specifier" | "enum_specifier" => {
            type_body(node, text, out);
        }
        "type_definition" => typedef(node, text, out),
        "alias_declaration" => push_field(node, "name", ItemKind::Type, text, out),
        "concept_definition" => push_field(node, "name", ItemKind::Trait, text, out),
        "namespace_definition" => namespace(node, text, out),
        "preproc_def" | "preproc_function_def" => {
            push_field(node, "name", ItemKind::Macro, text, out);
        }
        kind if TRANSPARENT.contains(&kind) => scope(node, text, in_type, out),
        _ => {}
    }
}

fn function(node: Node<'_>, text: &str, in_type: bool, out: &mut Vec<OutlineItem>) {
    let Some(declarator) = node.child_by_field_name("declarator") else {
        return;
    };
    if let Some((name, qualified)) = function_name(declarator, text) {
        let kind = if in_type || qualified {
            ItemKind::Method
        } else {
            ItemKind::Fn
        };
        push(node, name, kind, text, out);
    }
}

fn declaration(node: Node<'_>, text: &str, in_type: bool, out: &mut Vec<OutlineItem>) {
    if let Some(ty) = node.child_by_field_name("type")
        && ty.child_by_field_name("body").is_some()
    {
        type_body(ty, text, out);
    }
    let mut cursor = node.walk();
    for child in node.children_by_field_name("declarator", &mut cursor) {
        let declarator = child
            .child_by_field_name("declarator")
            .filter(|_| child.kind() == "init_declarator")
            .unwrap_or(child);
        if let Some((name, qualified)) = function_name(declarator, text) {
            let kind = if in_type || qualified {
                ItemKind::Method
            } else {
                ItemKind::Fn
            };
            push(node, name, kind, text, out);
        } else if !in_type && let Some(name) = plain_name(declarator, text) {
            push(node, name, ItemKind::Static, text, out);
        }
    }
}

fn type_body(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    let Some(body) = node.child_by_field_name("body") else {
        return;
    };
    if let Some(name) = node.child_by_field_name("name") {
        let kind = match node.kind() {
            "class_specifier" => ItemKind::Class,
            "union_specifier" => ItemKind::Union,
            "enum_specifier" => ItemKind::Enum,
            _ => ItemKind::Struct,
        };
        push(node, node_text(name, text), kind, text, out);
    }
    scope(body, text, true, out);
}

fn typedef(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    if let Some(ty) = node.child_by_field_name("type") {
        type_body(ty, text, out);
    }
    let mut cursor = node.walk();
    for declarator in node.children_by_field_name("declarator", &mut cursor) {
        if let Some(name) = plain_name(declarator, text) {
            push(node, name, ItemKind::Type, text, out);
        }
    }
}

fn namespace(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    if let Some(name) = node.child_by_field_name("name") {
        push(node, node_text(name, text), ItemKind::Namespace, text, out);
    }
    if let Some(body) = node.child_by_field_name("body") {
        scope(body, text, false, out);
    }
}

fn push_field(node: Node<'_>, field: &str, kind: ItemKind, text: &str, out: &mut Vec<OutlineItem>) {
    if let Some(name) = node.child_by_field_name(field) {
        push(node, node_text(name, text), kind, text, out);
    }
}

fn push(node: Node<'_>, name: String, kind: ItemKind, text: &str, out: &mut Vec<OutlineItem>) {
    if name.is_empty() {
        return;
    }
    let name_start_byte = super::symbol::name_start_byte(node, &name, text);
    out.push(OutlineItem {
        name,
        kind,
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
        name_start_byte,
        signature: c_docs::signature(node, text),
        doc: c_docs::doc(node, text),
    });
}
