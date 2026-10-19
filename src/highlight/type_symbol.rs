use super::symbol;
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

pub fn names_type(syntax: &TreeSyntax, byte: u32) -> bool {
    syntax
        .tree
        .as_ref()
        .is_some_and(|tree| symbol::names_type(tree, byte, syntax.grammar.symbol_kinds))
}

pub fn type_parameter(syntax: &TreeSyntax, text: &str, byte: u32) -> Option<String> {
    let tree = syntax.tree.as_ref()?;
    let node = symbol::symbol_node(tree, byte, syntax.grammar.symbol_kinds)?;
    super::rust_type_names::type_parameter(node, text)
}

pub fn enclosing_type(syntax: &TreeSyntax, text: &str, byte: u32) -> Option<String> {
    let tree = syntax.tree.as_ref()?;
    let node = symbol::symbol_node(tree, byte, syntax.grammar.symbol_kinds)?;
    super::rust_type_names::enclosing_impl(node, text)
}
