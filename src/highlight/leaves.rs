use tree_sitter::{Node, Tree};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Leaf {
    pub kind: String,
    pub text: String,
    pub start: u32,
    pub end: u32,
    pub import: bool,
}

pub fn collect(tree: &Tree, text: &str) -> Vec<Leaf> {
    let mut out = Vec::new();
    walk(tree.root_node(), text, false, &mut out);
    out
}

fn walk(node: Node<'_>, text: &str, import: bool, out: &mut Vec<Leaf>) {
    let import = import || matches!(node.kind(), "use_declaration" | "preproc_include");
    if matches!(node.kind(), "comment" | "line_comment" | "block_comment") {
        push(node, text, import, out);
        return;
    }
    let count = node.child_count();
    if count == 0 {
        push(node, text, import, out);
        return;
    }
    for index in 0..count {
        if let Some(child) = node.child(index) {
            walk(child, text, import, out);
        }
    }
}

fn push(node: Node<'_>, text: &str, import: bool, out: &mut Vec<Leaf>) {
    let start = node.start_byte();
    let end = node.end_byte();
    if start >= end || end > text.len() {
        return;
    }
    let Some(slice) = text.get(start..end) else {
        return;
    };
    if slice.chars().all(char::is_whitespace) {
        return;
    }
    out.push(Leaf {
        kind: node.kind().to_string(),
        text: slice.to_string(),
        start: start as u32,
        end: end as u32,
        import,
    });
}
