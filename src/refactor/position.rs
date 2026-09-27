use tree_sitter::Node;

use super::tree::{field_of, has_ancestor};

const NON_VALUE_PARENTS: [&str; 12] = [
    "scoped_identifier",
    "scoped_type_identifier",
    "shorthand_field_initializer",
    "macro_invocation",
    "use_declaration",
    "use_list",
    "scoped_use_list",
    "use_as_clause",
    "closure_parameters",
    "parameter",
    "parameter_declaration",
    "attribute",
];

const ASSIGN_KINDS: [&str; 3] = [
    "assignment_expression",
    "compound_assignment_expr",
    "update_expression",
];

const NON_VALUE_FIELDS: [&str; 9] = [
    "pattern",
    "name",
    "declarator",
    "macro",
    "type",
    "path",
    "field",
    "label",
    "parameters",
];

pub fn value_position(node: Node<'_>) -> bool {
    let Some(parent) = node.parent() else {
        return false;
    };
    let kind = parent.kind();
    if NON_VALUE_PARENTS.contains(&kind)
        || kind.ends_with("_pattern")
        || kind.ends_with("_declarator")
    {
        return false;
    }
    let field = field_of(node);
    if field.is_some_and(|f| NON_VALUE_FIELDS.contains(&f)) {
        return false;
    }
    if ASSIGN_KINDS.contains(&kind) && field != Some("right") {
        return false;
    }
    !has_ancestor(node, &["token_tree", "attribute_item"])
}
