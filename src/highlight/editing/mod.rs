mod brackets;
mod enclosing;
mod folds;
mod kinds;

pub use brackets::pair as bracket_pair;
pub use enclosing::{markdown as markdown_enclosing, ranges as enclosing_ranges};
pub use folds::{c_folds, cmake_folds, make_folds, markdown_folds, rust_folds, toml_folds};
pub use kinds::EditingKinds;
