use tree_sitter::Tree;

use crate::ffi::FoldRange;
use crate::highlight::walk::each_node;

use super::lines::{braced, closed, finish, runs, span};

const BODIES: &[(&str, &str)] = &[
    ("function_item", "fn"),
    ("impl_item", "impl"),
    ("trait_item", "trait"),
    ("mod_item", "mod"),
    ("struct_item", "struct"),
    ("enum_item", "enum"),
    ("match_expression", "match"),
];

pub fn folds(tree: &Tree, text: &str) -> Vec<FoldRange> {
    let mut out = Vec::new();
    let mut comments = Vec::new();
    let mut uses = Vec::new();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        "block" => {
            if node.parent().is_none_or(|p| p.kind() != "function_item") {
                braced(&mut out, text, node, "block");
            }
        }
        "block_comment" => closed(
            &mut out,
            text,
            node.start_byte(),
            node.end_byte(),
            "comment",
        ),
        "line_comment" => comments.push(span(node)),
        "use_declaration" => uses.push(span(node)),
        kind => {
            if let Some((_, fold)) = BODIES.iter().find(|(k, _)| *k == kind)
                && let Some(body) = node.child_by_field_name("body")
            {
                braced(&mut out, text, body, fold);
            }
        }
    });
    runs(&mut out, text, &comments, "comment");
    runs(&mut out, text, &uses, "use");
    finish(out)
}
