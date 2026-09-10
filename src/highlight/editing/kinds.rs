use tree_sitter::Tree;

use crate::ffi::FoldRange;

pub struct EditingKinds {
    pub strings: &'static [&'static str],
    pub comments: &'static [&'static str],
    pub bodies: &'static [&'static str],
    pub folds: fn(&Tree, &str) -> Vec<FoldRange>,
}
