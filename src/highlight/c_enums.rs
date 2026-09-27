use tree_sitter::Node;

use crate::ffi::{ItemKind, OutlineItem};

use super::c_names::{node_text, plain_name};
use super::c_scopes::namespace_path;
use super::types::TypeTable;
use super::visibility::Visibility;

enum Owner {
    File,
    Namespace(String, Visibility),
    Type(String, Visibility),
    Block(Visibility),
}

pub fn enumerators(table: &mut TypeTable, node: Node<'_>, text: &str) {
    let Some(body) = node.child_by_field_name("body") else {
        return;
    };
    let items = items(body, text);
    if !is_scoped(node) {
        declare_in_owner(table, owner(node, text), &items);
    }
    if let Some(name) = enum_name(node, text) {
        table.add_members(name, items);
    }
}

fn declare_in_owner(table: &mut TypeTable, owner: Owner, items: &[OutlineItem]) {
    let visibility = match owner {
        Owner::File => Visibility::Everywhere,
        Owner::Namespace(path, visibility) => {
            table.add_scope(path, items.to_vec());
            visibility
        }
        Owner::Type(name, visibility) => {
            table.add_members(name, items.to_vec());
            visibility
        }
        Owner::Block(visibility) => visibility,
    };
    for item in items {
        table.add_unqualified(item.clone(), visibility);
    }
}

fn owner(node: Node<'_>, text: &str) -> Owner {
    let mut current = node.parent();
    while let Some(scope) = current {
        let within = Visibility::Within(scope.start_byte() as u32, scope.end_byte() as u32);
        match scope.kind() {
            "field_declaration_list" => {
                return match scope.parent().and_then(|t| t.child_by_field_name("name")) {
                    Some(name) => Owner::Type(node_text(name, text), within),
                    None => Owner::Block(within),
                };
            }
            "declaration_list"
                if scope
                    .parent()
                    .is_some_and(|p| p.kind() == "namespace_definition") =>
            {
                let path = scope
                    .parent()
                    .map(|p| namespace_path(p, text))
                    .unwrap_or_default();
                if !path.is_empty() {
                    return Owner::Namespace(path, within);
                }
            }
            "compound_statement" => return Owner::Block(within),
            _ => {}
        }
        current = scope.parent();
    }
    Owner::File
}

fn items(body: Node<'_>, text: &str) -> Vec<OutlineItem> {
    let mut cursor = body.walk();
    body.named_children(&mut cursor)
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
        .collect()
}

fn is_scoped(node: Node<'_>) -> bool {
    let mut cursor = node.walk();
    node.children(&mut cursor)
        .any(|c| matches!(c.kind(), "class" | "struct"))
}

fn enum_name(node: Node<'_>, text: &str) -> Option<String> {
    if let Some(name) = node.child_by_field_name("name") {
        return Some(node_text(name, text));
    }
    let typedef = node.parent().filter(|p| p.kind() == "type_definition")?;
    plain_name(typedef.child_by_field_name("declarator")?, text)
}
