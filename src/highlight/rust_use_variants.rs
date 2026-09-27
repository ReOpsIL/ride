use tree_sitter::Node;

use crate::ffi::{ItemKind, OutlineItem};

use super::symbol::node_text;
use super::types::TypeTable;
use super::visibility::Visibility;

struct Import {
    owner: String,
    only: Option<String>,
    alias: Option<String>,
    visibility: Visibility,
}

pub fn register(table: &mut TypeTable, uses: &[Node<'_>], text: &str) {
    let mut imports = Vec::new();
    for node in uses {
        if let Some(argument) = node.child_by_field_name("argument") {
            let visibility = visibility(*node);
            clause(argument, None, text, visibility, &mut imports);
        }
    }
    for import in imports {
        for variant in imported(table, &import) {
            table.add_unqualified(variant, import.visibility);
        }
    }
}

fn visibility(use_node: Node<'_>) -> Visibility {
    match use_node.parent() {
        Some(scope) if scope.kind() != "source_file" => {
            Visibility::Within(scope.start_byte() as u32, scope.end_byte() as u32)
        }
        _ => Visibility::Everywhere,
    }
}

fn imported(table: &TypeTable, import: &Import) -> Vec<OutlineItem> {
    table
        .members_of(&import.owner)
        .into_iter()
        .flatten()
        .filter(|item| item.kind == ItemKind::Variant)
        .filter(|item| import.only.as_ref().is_none_or(|only| *only == item.name))
        .map(|item| {
            let mut item = item.clone();
            if let Some(alias) = &import.alias {
                item.name = alias.clone();
            }
            item
        })
        .collect()
}

fn clause(
    node: Node<'_>,
    owner: Option<&str>,
    text: &str,
    visibility: Visibility,
    out: &mut Vec<Import>,
) {
    let mut push = |owner: String, only: Option<String>, alias: Option<String>| {
        out.push(Import {
            owner,
            only,
            alias,
            visibility,
        });
    };
    match node.kind() {
        "use_wildcard" => {
            if let Some(path) = node.named_child(0) {
                push(last_segment(path, text), None, None);
            }
        }
        "scoped_identifier" => {
            if let Some((path_owner, name)) = split(node, text) {
                push(path_owner, Some(name), None);
            }
        }
        "use_as_clause" => {
            let alias = node
                .child_by_field_name("alias")
                .map(|a| node_text(a, text));
            let target = node.child_by_field_name("path");
            match target.map(|t| (t.kind(), t)) {
                Some(("scoped_identifier", t)) => {
                    if let Some((path_owner, name)) = split(t, text) {
                        push(path_owner, Some(name), alias);
                    }
                }
                Some(("identifier", t)) => {
                    if let Some(owner) = owner {
                        push(owner.to_string(), Some(node_text(t, text)), alias);
                    }
                }
                _ => {}
            }
        }
        "scoped_use_list" => {
            let list_owner = node
                .child_by_field_name("path")
                .map(|p| last_segment(p, text));
            if let Some(list) = node.child_by_field_name("list") {
                clause(list, list_owner.as_deref(), text, visibility, out);
            }
        }
        "use_list" => {
            let mut cursor = node.walk();
            for item in node.named_children(&mut cursor) {
                clause(item, owner, text, visibility, out);
            }
        }
        "identifier" => {
            if let Some(owner) = owner {
                push(owner.to_string(), Some(node_text(node, text)), None);
            }
        }
        _ => {}
    }
}

fn split(scoped: Node<'_>, text: &str) -> Option<(String, String)> {
    let path = scoped.child_by_field_name("path")?;
    let name = scoped.child_by_field_name("name")?;
    Some((last_segment(path, text), node_text(name, text)))
}

fn last_segment(path: Node<'_>, text: &str) -> String {
    path.child_by_field_name("name")
        .map_or_else(|| node_text(path, text), |name| node_text(name, text))
}
