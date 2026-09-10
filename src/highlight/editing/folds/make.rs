use tree_sitter::{Node, Tree};

use crate::ffi::FoldRange;
use crate::highlight::walk::each_node;

use super::lines::{between, closed, finish, last_content, region};

pub fn folds(tree: &Tree, text: &str) -> Vec<FoldRange> {
    let mut out = Vec::new();
    each_node(tree.root_node(), &mut |node| match node.kind() {
        "define_directive" => closed(&mut out, text, node.start_byte(), node.end_byte(), "define"),
        "rule" => rule(&mut out, text, node),
        "conditional" => conditional(&mut out, text, node),
        _ => {}
    });
    finish(out)
}

fn rule(out: &mut Vec<FoldRange>, text: &str, node: Node<'_>) {
    let mut cursor = node.walk();
    let Some(recipe) = node
        .named_children(&mut cursor)
        .find(|c| c.kind() == "recipe")
    else {
        return;
    };
    let mut cursor = recipe.walk();
    let Some(last) = recipe
        .named_children(&mut cursor)
        .filter(|c| c.kind() == "recipe_line")
        .last()
    else {
        return;
    };
    region(out, text, node.start_byte(), last.end_byte(), "rule");
}

fn conditional(out: &mut Vec<FoldRange>, text: &str, node: Node<'_>) {
    let mut starts = Vec::new();
    branches(node, &mut starts);
    let close = last_content(text, node.start_byte(), node.end_byte());
    between(out, text, &starts, close, "if");
}

fn branches(node: Node<'_>, starts: &mut Vec<usize>) {
    starts.push(node.start_byte());
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        if child.kind() == "else_directive" {
            branches(child, starts);
        }
    }
}
