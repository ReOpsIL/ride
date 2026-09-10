use tree_sitter::{Language, Node, Tree};

use crate::ffi::OutlineItem;
use crate::highlight::includes::IncludeRef;
use crate::highlight::site::Classifier;
use crate::highlight::types::TypeTable;

pub mod c;
pub mod cmake;
pub mod cpp;
pub mod make;
pub mod rust;
pub mod toml;

pub struct Grammar {
    pub language: Language,
    pub highlights: &'static str,
    pub keywords: &'static [&'static str],
    pub local_kinds: &'static [&'static str],
    pub declares: crate::highlight::locals::Declares,
    pub symbol_kinds: &'static [&'static str],
    pub qualifier: fn(Node<'_>, &str) -> Option<String>,
    pub outline: fn(&Tree, &str) -> Vec<OutlineItem>,
    pub member_ops: &'static [&'static str],
    pub member_kinds: &'static [&'static str],
    pub receiver: crate::highlight::members::Receiver,
    pub type_table: fn(&Tree, &str) -> TypeTable,
    pub includes: fn(&Tree, &str) -> Vec<IncludeRef>,
    pub site: Classifier,
    pub imports: fn(&Tree, &str) -> Vec<String>,
}
