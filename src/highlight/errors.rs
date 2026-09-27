use tree_sitter::Node;

use crate::ffi::ParseErrorSpan;

pub fn collect(root: Node<'_>) -> Vec<ParseErrorSpan> {
    let mut out = Vec::new();
    if !root.has_error() {
        return out;
    }
    let mut cursor = root.walk();
    loop {
        let node = cursor.node();
        if node.is_error() || node.is_missing() {
            out.push(ParseErrorSpan {
                start_byte: node.start_byte() as u32,
                end_byte: node.end_byte() as u32,
            });
        }
        if node.has_error() && !node.is_error() && cursor.goto_first_child() {
            continue;
        }
        while !cursor.goto_next_sibling() {
            if !cursor.goto_parent() {
                return out;
            }
        }
    }
}
