use tree_sitter::{Language, Node, Tree};

use crate::ffi::OutlineItem;
use crate::highlight::includes::IncludeRef;
use crate::highlight::types::TypeTable;

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
    pub member_ops: &'static [&'static str],
    pub member_kinds: &'static [&'static str],
    pub receiver_type: fn(&Tree, &str, Node<'_>) -> Option<String>,
    pub type_table: fn(&Tree, &str) -> TypeTable,
    pub includes: fn(&Tree, &str) -> Vec<IncludeRef>,
}
