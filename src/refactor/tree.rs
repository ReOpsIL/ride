use tree_sitter::Node;

pub fn field_of<'t>(node: Node<'t>) -> Option<&'t str> {
    let parent = node.parent()?;
    let mut cursor = parent.walk();
    let index = parent
        .children(&mut cursor)
        .position(|child| child.id() == node.id())?;
    parent.field_name_for_child(u32::try_from(index).ok()?)
}

pub fn has_ancestor(node: Node<'_>, kinds: &[&str]) -> bool {
    let mut current = node.parent();
    while let Some(n) = current {
        if kinds.contains(&n.kind()) {
            return true;
        }
        current = n.parent();
    }
    false
}
