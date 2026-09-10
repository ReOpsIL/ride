use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};

use super::c_names::node_text;
use super::walk::each_node;

pub fn outline(tree: &Tree, text: &str) -> Vec<OutlineItem> {
    let mut out = Vec::new();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        "rule" => targets(node, text, &mut out),
        "variable_assignment" | "define_directive" | "shell_assignment" => {
            if let Some(name) = node.child_by_field_name("name") {
                push(node, node_text(name, text), ItemKind::Static, &mut out);
            }
        }
        _ => {}
    });
    out
}

fn targets(rule: Node<'_>, text: &str, out: &mut Vec<OutlineItem>) {
    let mut cursor = rule.walk();
    let Some(targets) = rule
        .named_children(&mut cursor)
        .find(|c| c.kind() == "targets")
    else {
        return;
    };
    let mut cursor = targets.walk();
    for word in targets.named_children(&mut cursor) {
        if word.kind() == "word" {
            push(rule, node_text(word, text), ItemKind::Target, out);
        }
    }
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
