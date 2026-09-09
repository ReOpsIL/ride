use tree_sitter::Node;

pub fn child_at(node: Node<'_>, i: usize) -> Option<Node<'_>> {
    let i = u32::try_from(i).ok()?;
    node.named_child(i)
}

pub fn each_named(node: Node<'_>, mut visit: impl FnMut(Node<'_>)) {
    for i in 0..node.named_child_count() {
        if let Some(child) = child_at(node, i) {
            visit(child);
        }
    }
}
