use tree_sitter::Node;

use super::item::Visibility;

pub fn visibility(node: Node<'_>, source: &str) -> Visibility {
    for i in 0..node.named_child_count() {
        let Some(child) = super::ts::child_at(node, i) else {
            continue;
        };
        if child.kind() != "visibility_modifier" {
            continue;
        }
        let text = child.utf8_text(source.as_bytes()).unwrap_or("");
        if text == "pub" {
            return Visibility::Pub;
        }
        return Visibility::Crate;
    }
    Visibility::Private
}

pub fn effective_vis(own: Visibility, default: Option<Visibility>, trait_impl: bool) -> Visibility {
    if own != Visibility::Private {
        return own;
    }
    if let Some(d) = default {
        return d;
    }
    if trait_impl {
        return Visibility::Pub;
    }
    Visibility::Private
}
