use tree_sitter::Node;

pub fn has_attr(node: Node<'_>, source: &str, name: &str) -> bool {
    any_attr(node, |attr| {
        attr_ident(attr, source).as_deref() == Some(name)
    })
}

pub fn is_deprecated(node: Node<'_>, source: &str) -> bool {
    has_attr(node, source, "deprecated")
}

pub fn is_test_only(node: Node<'_>, source: &str) -> bool {
    any_attr(node, |attr| {
        let ident = attr_ident(attr, source).unwrap_or_default();
        ident == "test"
            || ident.ends_with("::test")
            || (ident == "cfg" && cfg_is_test(attr, source))
    })
}

pub fn path_attribute(node: Node<'_>, source: &str) -> Option<String> {
    let mut found = None;
    each_attr(node, |attr| {
        if let Some(p) = parse_path_attr(attr, source) {
            found = Some(p);
        }
    });
    found
}

fn any_attr(node: Node<'_>, mut pred: impl FnMut(Node<'_>) -> bool) -> bool {
    let mut found = false;
    each_attr(node, |attr| found |= pred(attr));
    found
}

fn each_attr(node: Node<'_>, mut visit: impl FnMut(Node<'_>)) {
    let mut sib = node.prev_named_sibling();
    while let Some(s) = sib {
        match s.kind() {
            "attribute_item" => {
                if let Some(attr) = s.named_child(0) {
                    visit(attr);
                }
            }
            "line_comment" | "block_comment" => {}
            _ => break,
        }
        sib = s.prev_named_sibling();
    }
}

fn attr_ident(attr: Node<'_>, source: &str) -> Option<String> {
    let name = attr.named_child(0)?;
    name.utf8_text(source.as_bytes()).ok().map(str::to_string)
}

fn cfg_is_test(attr: Node<'_>, source: &str) -> bool {
    let Some(args) = attr.child_by_field_name("arguments") else {
        return false;
    };
    let text: String = args
        .utf8_text(source.as_bytes())
        .unwrap_or("")
        .chars()
        .filter(|c| !c.is_whitespace())
        .collect();
    text == "(test)" || text.starts_with("(all(test,")
}

fn parse_path_attr(attr: Node<'_>, source: &str) -> Option<String> {
    if attr_ident(attr, source).as_deref() != Some("path") {
        return None;
    }
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
