use tree_sitter::{Node, Tree};

use crate::ffi::FoldRange;
use crate::highlight::walk::each_node;

use super::lines::{between, finish, last_content};

const BLOCKS: &[(&str, &str)] = &[
    ("function_def", "function"),
    ("macro_def", "macro"),
    ("if_condition", "if"),
    ("foreach_loop", "foreach"),
    ("while_loop", "while"),
];

const BRANCHES: &[&str] = &["elseif_command", "else_command"];

pub fn folds(tree: &Tree, text: &str) -> Vec<FoldRange> {
    let mut out = Vec::new();
    each_node(tree.root_node(), &mut |node| {
        if let Some((_, kind)) = BLOCKS.iter().find(|(k, _)| *k == node.kind()) {
            block(&mut out, text, node, kind);
        }
    });
    finish(out)
}

fn block(out: &mut Vec<FoldRange>, text: &str, node: Node<'_>, kind: &str) {
    let mut cursor = node.walk();
    let mut starts = vec![node.start_byte()];
    starts.extend(
        node.named_children(&mut cursor)
            .filter(|c| BRANCHES.contains(&c.kind()))
            .map(|c| c.start_byte()),
    );
    let close = last_content(text, node.start_byte(), node.end_byte());
    between(out, text, &starts, close, kind);
}
