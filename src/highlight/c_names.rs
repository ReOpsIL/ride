use tree_sitter::Node;

pub use super::symbol::node_text;

pub const NAME_KINDS: [&str; 6] = [
    "identifier",
    "field_identifier",
    "type_identifier",
    "destructor_name",
    "operator_name",
    "namespace_identifier",
];

pub const WRAPPERS: [&str; 3] = [
    "pointer_declarator",
    "reference_declarator",
    "parenthesized_declarator",
];

pub const SPECIFIERS: [&str; 3] = ["struct_specifier", "class_specifier", "union_specifier"];

pub fn function_name(declarator: Node<'_>, text: &str) -> Option<(String, bool)> {
    function_name_node(declarator).map(|(name, qualified)| (node_text(name, text), qualified))
}

pub fn function_name_node(declarator: Node<'_>) -> Option<(Node<'_>, bool)> {
    let mut node = declarator;
    while WRAPPERS.contains(&node.kind()) {
        node = wrapped(node)?;
    }
    if node.kind() != "function_declarator" {
        return None;
    }
    let inner = node.child_by_field_name("declarator")?;
    let qualified = inner.kind() == "qualified_identifier";
    plain_name_node(inner).map(|name| (name, qualified))
}

pub fn plain_name(declarator: Node<'_>, text: &str) -> Option<String> {
    plain_name_node(declarator).map(|name| node_text(name, text))
}

pub fn plain_name_node(declarator: Node<'_>) -> Option<Node<'_>> {
    let mut node = declarator;
    loop {
        if NAME_KINDS.contains(&node.kind()) {
            return Some(node);
        }
        node = match node.kind() {
            k if WRAPPERS.contains(&k) => wrapped(node)?,
            "array_declarator" | "attributed_declarator" | "init_declarator" => {
                node.child_by_field_name("declarator")?
            }
            "qualified_identifier" | "template_function" | "template_method" => {
                node.child_by_field_name("name")?
            }
            _ => return None,
        };
    }
}

pub fn wrapped(node: Node<'_>) -> Option<Node<'_>> {
    node.child_by_field_name("declarator").or_else(|| {
        let mut cursor = node.walk();
        node.named_children(&mut cursor).last()
    })
}

pub fn type_name(node: Node<'_>, text: &str) -> Option<String> {
    match node.kind() {
        "type_identifier" => Some(node_text(node, text)),
        k if SPECIFIERS.contains(&k) => {
            node.child_by_field_name("name").map(|n| node_text(n, text))
        }
        "qualified_identifier" | "template_type" => node
            .child_by_field_name("name")
            .and_then(|n| type_name(n, text)),
        "type_descriptor" => node
            .child_by_field_name("type")
            .and_then(|n| type_name(n, text)),
        _ => None,
    }
}
