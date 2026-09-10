use tree_sitter::Node;

pub fn each_node<'a>(node: Node<'a>, f: &mut impl FnMut(Node<'a>)) {
    f(node);
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        each_node(child, f);
    }
}
