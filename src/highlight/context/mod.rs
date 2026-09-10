use tree_sitter::{Node, Tree};

mod c;
mod cmake;
mod make;
mod rust;
mod scan;
mod toml;

pub use c::c as c_context;
pub use cmake::cmake as cmake_context;
pub use make::make as make_context;
pub use rust::rust as rust_context;
pub use toml::toml as toml_context;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Context {
    Unknown,
    Item,
    Body,
    Fields,
    Statement,
    Expression,
    Type,
    Pattern,
    Attribute,
    Preprocessor,
    Use,
    Recipe,
    Function,
    Value,
    Argument,
    Case,
    Default,
    Table,
    Key,
}

pub type Detector = fn(Option<&Tree>, &str, usize) -> Context;

const NAMES: &[(Context, &str)] = &[
    (Context::Unknown, "unknown"),
    (Context::Item, "item"),
    (Context::Body, "body"),
    (Context::Fields, "fields"),
    (Context::Statement, "statement"),
    (Context::Expression, "expression"),
    (Context::Type, "type"),
    (Context::Pattern, "pattern"),
    (Context::Attribute, "attribute"),
    (Context::Preprocessor, "preprocessor"),
    (Context::Use, "use"),
    (Context::Recipe, "recipe"),
    (Context::Function, "function"),
    (Context::Value, "value"),
    (Context::Argument, "argument"),
    (Context::Case, "case"),
    (Context::Default, "default"),
    (Context::Table, "table"),
    (Context::Key, "key"),
];

impl Context {
    pub fn name(self) -> &'static str {
        NAMES
            .iter()
            .find(|(c, _)| *c == self)
            .map(|(_, n)| *n)
            .unwrap_or("unknown")
    }

    pub fn parse(name: &str) -> Option<Context> {
        NAMES.iter().find(|(_, n)| *n == name).map(|(c, _)| *c)
    }

    pub fn covers(self, got: Context) -> bool {
        self == got
            || (matches!(got, Context::Case | Context::Default)
                && matches!(
                    self,
                    Context::Statement | Context::Pattern | Context::Case | Context::Default
                ))
    }
}

pub(super) fn node_at(tree: Option<&Tree>, start: usize, at: usize) -> Option<Node<'_>> {
    let probe = if start < at {
        start
    } else {
        at.saturating_sub(1)
    };
    tree?.root_node().descendant_for_byte_range(probe, probe)
}

pub(super) fn ancestors<'a>(node: Node<'a>) -> impl Iterator<Item = Node<'a>> {
    std::iter::successors(Some(node), |n| n.parent()).take(24)
}
