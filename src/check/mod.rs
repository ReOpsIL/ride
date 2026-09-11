mod clang;
mod clang_parse;
mod clang_project;
mod compile_db;
mod fmt;
mod fmt_run;
mod fmt_rust;
mod include_dirs;
mod including;
mod make_fmt;
mod message;
mod offsets;
mod output;
mod parse;
mod run;

pub use clang::run_clang_check;
pub use clang_parse::parse_clang;
pub use clang_project::{merge_indexed, run_check_c_project};
pub use fmt::{
    Formatter, format_clang, format_document, format_range, format_source, selection_span,
};
pub use include_dirs::include_dirs;
pub use including::sources_including;
pub use make_fmt::format as format_make;
pub use parse::parse_lines;
pub use run::run_check;
