use tree_sitter::{Node, Tree};

use crate::ffi::{ItemKind, OutlineItem};

use super::walk::each_node;

pub fn outline(tree: &Tree, text: &str) -> Vec<OutlineItem> {
    let mut out = Vec::new();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        "rule" => targets(node, text, &mut out),
        "variable_assignment" | "define_directive" | "shell_assignment" => {
            if let Some(name) = node.child_by_field_name("name") {
                push(node, name, ItemKind::Static, text, &mut out);
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
            push(rule, word, ItemKind::Target, text, out);
        }
    }
}

fn push(node: Node<'_>, name: Node<'_>, kind: ItemKind, text: &str, out: &mut Vec<OutlineItem>) {
    out.extend(super::line_item::line_item(node, name, kind, text));
}
