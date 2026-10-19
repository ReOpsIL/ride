use tree_sitter::Node;

pub fn pick<'a>(
    hint: Option<Node<'a>>,
    root: Node<'a>,
    source: &str,
    byte: usize,
    name: &str,
    is_item: fn(&str) -> bool,
) -> Option<Node<'a>> {
    if let Some(node) = hint {
        match label(node, source) {
            Some(found) if name.is_empty() || found == name => return Some(node),
            Some(_) => {}
            None => return Some(node),
        }
    }
    closest(root, source, byte, name, is_item)
}

fn label<'a>(node: Node<'_>, source: &'a str) -> Option<&'a str> {
    node.child_by_field_name("name")
        .and_then(|n| n.utf8_text(source.as_bytes()).ok())
}

fn closest<'a>(
    root: Node<'a>,
    source: &str,
    byte: usize,
    name: &str,
    is_item: fn(&str) -> bool,
) -> Option<Node<'a>> {
    let mut best: Option<(usize, Node<'a>)> = None;
    collect(root, source, byte, name, is_item, &mut best);
    best.map(|(_, node)| node)
}

fn collect<'a>(
    node: Node<'a>,
    source: &str,
    byte: usize,
    name: &str,
    is_item: fn(&str) -> bool,
    best: &mut Option<(usize, Node<'a>)>,
) {
    if is_item(node.kind()) && label(node, source) == Some(name) && !name.is_empty() {
        let dist = node.start_byte().abs_diff(byte);
        if best.as_ref().is_none_or(|(have, _)| dist < *have) {
            *best = Some((dist, node));
        }
    }
    let mut walk = node.walk();
    if walk.goto_first_child() {
        loop {
            collect(walk.node(), source, byte, name, is_item, best);
            if !walk.goto_next_sibling() {
                break;
            }
        }
    }
}
