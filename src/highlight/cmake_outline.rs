use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};

use super::c_names::node_text;
use super::walk::each_node;

pub fn outline(tree: &Tree, text: &str) -> Vec<OutlineItem> {
    let mut out = Vec::new();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        "function_def" => definition(node, "function_command", ItemKind::Fn, text, &mut out),
        "macro_def" => definition(node, "macro_command", ItemKind::Macro, text, &mut out),
        "normal_command" => command(node, text, &mut out),
        _ => {}
    });
    out
}

fn definition(node: Node<'_>, head: &str, kind: ItemKind, text: &str, out: &mut Vec<OutlineItem>) {
    let mut cursor = node.walk();
    let Some(command) = node.named_children(&mut cursor).find(|c| c.kind() == head) else {
        return;
    };
    if let Some(name) = first_argument(command, text) {
        push(node, name, kind, out);
    }
}

fn command(node: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    let Some(identifier) = node.named_child(0).filter(|c| c.kind() == "identifier") else {
        return;
    };
    let kind = match node_text(identifier, text).to_ascii_lowercase().as_str() {
        "project" => ItemKind::Mod,
        "add_executable" | "add_library" | "add_custom_target" => ItemKind::Target,
        "set" => ItemKind::Static,
        "option" => ItemKind::Const,
        _ => return,
    };
    if let Some(name) = first_argument(node, text) {
        push(node, name, kind, out);
    }
}

fn first_argument(command: Node<'_>, text: &str) -> Option<String> {
    let mut cursor = command.walk();
    let list = command
        .named_children(&mut cursor)
        .find(|c| c.kind() == "argument_list")?;
    let mut cursor = list.walk();
    list.named_children(&mut cursor)
        .find(|c| c.kind() == "argument")
        .map(|a| node_text(a, text))
}

fn push(node: Node<'_>, name: String, kind: ItemKind, out: &mut Vec<OutlineItem>) {
    if !name.is_empty() {
        out.push(OutlineItem {
            name,
            kind,
            start_byte: node.start_byte() as u32,
            end_byte: node.end_byte() as u32,
        });
    }
}
