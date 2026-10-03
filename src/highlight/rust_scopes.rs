use tree_sitter::Node;

use crate::ffi::{OutlineItem, OutlineScope};

pub fn impl_scopes(root: Node<'_>, text: &str) -> Vec<OutlineScope> {
    let mut out = Vec::new();
    collect(root, text, &mut out);
    out
}

pub fn attach(items: &mut [OutlineItem], scopes: &[OutlineScope]) {
    for item in items {
        item.scope = innermost(scopes, item.start_byte).cloned();
    }
}

fn innermost(scopes: &[OutlineScope], byte: u32) -> Option<&OutlineScope> {
    scopes
        .iter()
        .filter(|s| s.start_byte < byte && byte < s.end_byte)
        .min_by_key(|s| s.end_byte - s.start_byte)
}

fn collect(node: Node<'_>, text: &str, out: &mut Vec<OutlineScope>) {
    if node.kind() == "impl_item"
        && let Some(scope) = scope(node, text)
    {
        out.push(scope);
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        collect(child, text, out);
    }
}

fn scope(node: Node<'_>, text: &str) -> Option<OutlineScope> {
    let body = node.child_by_field_name("body")?;
    let header = text.get(node.start_byte()..body.start_byte())?;
    Some(OutlineScope {
        label: header.split_whitespace().collect::<Vec<_>>().join(" "),
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
    })
}
