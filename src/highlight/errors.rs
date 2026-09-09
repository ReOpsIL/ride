use tree_sitter::Node;

use crate::ffi::ParseErrorSpan;

pub fn collect(root: Node<'_>) -> Vec<ParseErrorSpan> {
    let mut out = Vec::new();
    walk(root, &mut out);
    out
}

fn walk(node: Node<'_>, out: &mut Vec<ParseErrorSpan>) {
    if node.is_error() || node.is_missing() {
        out.push(ParseErrorSpan {
            start_byte: node.start_byte() as u32,
            end_byte: node.end_byte() as u32,
        });
    }
    for i in 0..node.named_child_count() {
        if let Some(child) = node.named_child(u32::try_from(i).unwrap_or(u32::MAX)) {
            walk(child, out);
        }
    }
}
