use tree_sitter::Tree;

use crate::ffi::FoldRange;

use super::lines::{finish, region};

pub fn folds(tree: &Tree, text: &str) -> Vec<FoldRange> {
    let root = tree.root_node();
    let mut out = Vec::new();
    let mut cursor = root.walk();
    for node in root.named_children(&mut cursor) {
        if matches!(node.kind(), "table" | "table_array_element") {
            region(&mut out, text, node.start_byte(), node.end_byte(), "table");
        }
    }
    finish(out)
}
