use tree_sitter::Node;

use crate::ffi::{ByteRange, StatementBounds};

pub fn range(root: Node<'_>, byte: u32, is_statement: fn(&str) -> bool) -> Option<ByteRange> {
    Some(bytes(node_at(root, byte, is_statement)?))
}

pub fn sibling(
    root: Node<'_>,
    byte: u32,
    up: bool,
    is_statement: fn(&str) -> bool,
) -> Option<ByteRange> {
    let found = bounds(root, byte, is_statement)?;
    if up { found.previous } else { found.next }
}

pub fn bounds(
    root: Node<'_>,
    byte: u32,
    is_statement: fn(&str) -> bool,
) -> Option<StatementBounds> {
    let node = node_at(root, byte, is_statement)?;
    let Some(parent) = node.parent() else {
        return Some(StatementBounds {
            current: bytes(node),
            previous: None,
            next: None,
        });
    };
    let mut cursor = parent.walk();
    let sibs: Vec<Node<'_>> = parent
        .named_children(&mut cursor)
        .filter(|child| is_statement(child.kind()))
        .collect();
    let i = sibs.iter().position(|child| child.id() == node.id());
    let (previous, next) = match i {
        Some(i) => (
            i.checked_sub(1)
                .and_then(|j| sibs.get(j))
                .map(|n| bytes(*n)),
            sibs.get(i + 1).map(|n| bytes(*n)),
        ),
        None => (None, None),
    };
    Some(StatementBounds {
        current: bytes(node),
        previous,
        next,
    })
}

pub fn rust(kind: &str) -> bool {
    matches!(
        kind,
        "expression_statement"
            | "let_declaration"
            | "use_declaration"
            | "extern_crate_declaration"
            | "macro_definition"
            | "associated_type"
    ) || (kind.ends_with("_item") && !matches!(kind, "attribute_item" | "inner_attribute_item"))
}

pub fn c(kind: &str) -> bool {
    kind.ends_with("_statement")
        || matches!(
            kind,
            "declaration" | "function_definition" | "for_range_loop"
        )
}

pub fn none(_: &str) -> bool {
    false
}

fn node_at<'a>(root: Node<'a>, byte: u32, is_statement: fn(&str) -> bool) -> Option<Node<'a>> {
    let at = (byte as usize).min(root.end_byte());
    let mut node = root.descendant_for_byte_range(at, at).or(Some(root));
    while let Some(n) = node {
        if is_statement(n.kind()) {
            return Some(n);
        }
        node = n.parent();
    }
    None
}

fn bytes(node: Node<'_>) -> ByteRange {
    ByteRange {
        start_byte: node.start_byte() as u32,
        end_byte: node.end_byte() as u32,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tree_sitter::{Language, Parser};

    fn caret(src: &str) -> (String, u32) {
        let at = src.find('|').expect("caret") as u32;
        let mut text = src.to_string();
        text.remove(at as usize);
        (text, at)
    }

    fn parse(language: Language, src: &str) -> (String, u32, tree_sitter::Tree) {
        let (text, at) = caret(src);
        let mut parser = Parser::new();
        parser.set_language(&language).unwrap();
        let tree = parser.parse(&text, None).unwrap();
        (text, at, tree)
    }

    fn snippet(text: &str, range: ByteRange) -> &str {
        &text[range.start_byte as usize..range.end_byte as usize]
    }

    fn rust_bounds(src: &str) -> (String, StatementBounds) {
        let (text, at, tree) = parse(Language::new(tree_sitter_rust::LANGUAGE), src);
        let found = bounds(tree.root_node(), at, rust).expect("bounds");
        (text, found)
    }

    fn c_bounds(src: &str) -> (String, StatementBounds) {
        let (text, at, tree) = parse(Language::new(tree_sitter_c::LANGUAGE), src);
        let found = bounds(tree.root_node(), at, c).expect("bounds");
        (text, found)
    }

    #[test]
    fn rust_bounds_name_previous_and_next_items() {
        let (text, found) = rust_bounds("fn a() {}\nfn b|() {}\nfn c() {}\n");
        assert_eq!(snippet(&text, found.current), "fn b() {}");
        assert_eq!(snippet(&text, found.previous.unwrap()), "fn a() {}");
        assert_eq!(snippet(&text, found.next.unwrap()), "fn c() {}");
    }

    #[test]
    fn rust_bounds_lets_inside_a_function() {
        let (text, found) =
            rust_bounds("fn f() {\n    let a = 1;\n    let b| = 2;\n    let c = 3;\n}\n");
        assert_eq!(snippet(&text, found.current), "let b = 2;");
        assert_eq!(snippet(&text, found.previous.unwrap()), "let a = 1;");
        assert_eq!(snippet(&text, found.next.unwrap()), "let c = 3;");
    }

    #[test]
    fn rust_bounds_first_item_has_no_previous() {
        let (text, found) = rust_bounds("fn a|() {}\nfn b() {}\n");
        assert_eq!(snippet(&text, found.current), "fn a() {}");
        assert!(found.previous.is_none());
        assert_eq!(snippet(&text, found.next.unwrap()), "fn b() {}");
    }

    #[test]
    fn c_bounds_name_previous_and_next_statements() {
        let (text, found) =
            c_bounds("int f(void) {\n    int a = 1;\n    int b| = 2;\n    return a;\n}\n");
        assert_eq!(snippet(&text, found.current), "int b = 2;");
        assert_eq!(snippet(&text, found.previous.unwrap()), "int a = 1;");
        assert_eq!(snippet(&text, found.next.unwrap()), "return a;");
    }

    #[test]
    fn c_bounds_last_statement_has_no_next() {
        let (text, found) = c_bounds("int a = 1;\nint b| = 2;\n");
        assert_eq!(snippet(&text, found.current), "int b = 2;");
        assert_eq!(snippet(&text, found.previous.unwrap()), "int a = 1;");
        assert!(found.next.is_none());
    }
}
