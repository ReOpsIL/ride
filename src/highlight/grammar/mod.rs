use tree_sitter::{Language, Node, Tree};

use crate::ffi::OutlineItem;

pub mod c;
pub mod cpp;
pub mod rust;

pub struct Grammar {
    pub language: Language,
    pub highlights: &'static str,
    pub keywords: &'static [&'static str],
    pub local_kinds: &'static [&'static str],
    pub symbol_kinds: &'static [&'static str],
    pub qualifier: fn(Node<'_>, &str) -> Option<String>,
    pub outline: fn(&Tree, &str) -> Vec<OutlineItem>,
}
