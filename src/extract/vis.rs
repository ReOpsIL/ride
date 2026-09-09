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

pub fn has_attr(node: Node<'_>, source: &str, name: &str) -> bool {
    let mut sib = node.prev_named_sibling();
    while let Some(s) = sib {
        match s.kind() {
            "attribute_item" => {
                if attr_ident(s, source).as_deref() == Some(name) {
                    return true;
                }
            }
            "line_comment" | "block_comment" => {}
            _ => break,
        }
        sib = s.prev_named_sibling();
    }
    false
}

pub fn path_attribute(node: Node<'_>, source: &str) -> Option<String> {
    let mut sib = node.prev_named_sibling();
    let mut found = None;
    while let Some(s) = sib {
        match s.kind() {
            "attribute_item" => {
                if let Some(p) = parse_path_attr(s, source) {
                    found = Some(p);
                }
            }
            "line_comment" | "block_comment" => {}
            _ => break,
        }
        sib = s.prev_named_sibling();
    }
    found
}

fn attr_ident(attr_item: Node<'_>, source: &str) -> Option<String> {
    let attr = attr_item.named_child(0)?;
    let name = attr.named_child(0)?;
    name.utf8_text(source.as_bytes()).ok().map(str::to_string)
}

fn parse_path_attr(attr_item: Node<'_>, source: &str) -> Option<String> {
    if attr_ident(attr_item, source).as_deref() != Some("path") {
        return None;
    }
    let attr = attr_item.named_child(0)?;
    let value = attr.child_by_field_name("value")?;
    let raw = value.utf8_text(source.as_bytes()).ok()?;
    Some(unquote(raw))
}

fn unquote(raw: &str) -> String {
    let t = raw.trim();
    if let Some(s) = t.strip_prefix("r#\"") {
        return s.trim_end_matches('"').trim_end_matches('#').to_string();
    }
    t.trim_matches('"').to_string()
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
