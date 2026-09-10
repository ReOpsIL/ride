use tree_sitter::Node;

use crate::ffi::FoldRange;
use crate::highlight::walk::each_node;

use super::lines::{closed, finish, region};

const HEADINGS: &[&str] = &["atx_heading", "setext_heading"];

pub fn folds(root: Node<'_>, text: &str) -> Vec<FoldRange> {
    let mut out = Vec::new();
    each_node(root, &mut |node| match node.kind() {
        "section" => section(&mut out, text, node),
        "fenced_code_block" => closed(&mut out, text, node.start_byte(), node.end_byte(), "fence"),
        _ => {}
    });
    finish(out)
}

fn section(out: &mut Vec<FoldRange>, text: &str, node: Node<'_>) {
    let mut cursor = node.walk();
    let Some(heading) = node
        .named_children(&mut cursor)
        .find(|c| HEADINGS.contains(&c.kind()))
    else {
        return;
    };
    let head = heading
        .end_byte()
        .saturating_sub(1)
        .max(heading.start_byte());
    region(out, text, head, node.end_byte(), "section");
}
