use tree_sitter::Tree;

use super::site::use_leaf_names;
use super::walk::each_node;

pub fn rust_imports(tree: &Tree, text: &str) -> Vec<String> {
    let mut out = Vec::new();
    each_node(tree.root_node(), &mut |node| {
        if node.kind() != "use_declaration" {
            return;
        }
        let Ok(body) = node.utf8_text(text.as_bytes()) else {
            return;
        };
        let Some(pos) = body.find("use") else {
            return;
        };
        out.extend(use_leaf_names(&body[pos + 3..]));
    });
    out.sort();
    out.dedup();
    out
}

pub fn no_imports(_: &Tree, _: &str) -> Vec<String> {
    Vec::new()
}
