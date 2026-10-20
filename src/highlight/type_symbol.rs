use super::rust_type_names::TypeParam;
use super::symbol;
use super::symbol_role::SymbolRole;
use super::tree_parser::TreeSyntax;

pub fn symbol_at(syntax: &TreeSyntax, text: &str, byte: u32) -> Option<crate::ffi::SymbolAt> {
    let tree = syntax.tree.as_ref()?;
    symbol::symbol_at(
        tree,
        text,
        byte,
        syntax.grammar.symbol_kinds,
        syntax.grammar.qualifier,
    )
}

pub fn symbol_role(syntax: &TreeSyntax, byte: u32) -> SymbolRole {
    syntax
        .tree
        .as_ref()
        .and_then(|tree| symbol::symbol_node(tree, byte, syntax.grammar.symbol_kinds))
        .map_or(SymbolRole::Other, syntax.grammar.role)
}

pub fn type_parameter(syntax: &TreeSyntax, text: &str, byte: u32) -> Option<TypeParam> {
    let tree = syntax.tree.as_ref()?;
    let node = symbol::symbol_node(tree, byte, syntax.grammar.symbol_kinds)?;
    super::rust_type_names::type_parameter(node, text)
}

pub fn enclosing_type(syntax: &TreeSyntax, text: &str, byte: u32) -> Option<String> {
    let tree = syntax.tree.as_ref()?;
    let node = symbol::symbol_node(tree, byte, syntax.grammar.symbol_kinds)?;
    super::rust_type_names::enclosing_impl(node, text)
}
