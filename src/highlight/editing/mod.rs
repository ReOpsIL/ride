mod brackets;
mod complete;
mod complete_kind;
mod enclosing;
mod folds;
mod kinds;
mod statement;

pub use brackets::pair as bracket_pair;
pub use complete::{edit as complete, new_line};
pub use enclosing::{markdown as markdown_enclosing, ranges as enclosing_ranges};
pub use folds::{c_folds, cmake_folds, make_folds, markdown_folds, rust_folds, toml_folds};
pub use kinds::EditingKinds;
pub use statement::{
    c as c_statement, none as no_statement, range as statement_range, rust as rust_statement,
    sibling as sibling_statement,
};
