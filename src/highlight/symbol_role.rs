use tree_sitter::Node;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SymbolRole {
    Primitive,
    Type,
    Qualifier,
    Other,
}

pub fn plain(node: Node<'_>) -> SymbolRole {
    match node.kind() {
        "type_identifier" | "primitive_type" => SymbolRole::Type,
        _ => SymbolRole::Other,
    }
}

pub fn rust(node: Node<'_>) -> SymbolRole {
    match node.kind() {
        "primitive_type" => SymbolRole::Primitive,
        "type_identifier" => SymbolRole::Type,
        _ if heads_path(node) => SymbolRole::Qualifier,
        _ => SymbolRole::Other,
    }
}

fn heads_path(node: Node<'_>) -> bool {
    node.parent().is_some_and(|parent| {
        matches!(
            parent.kind(),
            "scoped_identifier" | "scoped_type_identifier"
        ) && parent
            .child_by_field_name("path")
            .is_some_and(|path| path.id() == node.id())
    })
}
