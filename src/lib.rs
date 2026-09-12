uniffi::setup_scaffolding!();

mod cheatsheet;
mod check;
pub mod debug;
mod discover;
mod engine;
mod error;
mod extract;
mod ffi;
mod highlight;
pub mod includes;
mod index;
mod markdown;
mod params;
pub mod project;
mod query;
mod run;
mod score;
mod skip;
mod text;
mod toolchain;

pub use cheatsheet::{Entry, Section, Selected, Sheet, SheetError, select, sheet, validate};
pub use check::{
    Formatter, format_clang, format_document, format_make, format_range, format_source,
    include_dirs, merge_indexed, parse_clang, parse_lines, run_check, run_check_c_project,
    run_clang_check, sources_including,
};
pub use debug::adapter::{adapter_path, find_adapter};
pub use debug::filters::{exception_filters, probe_exception_filters};
pub use debug::registry::DebugRegistry;
pub use debug::session::DebugSession;
pub use debug::transport::Transport;
pub use discover::{
    CrateTarball, DiscoveredCrate, Discovery, SystemIncludes, cargo_home, discover, probe_args,
    rustc_sysroot, sysroot_path, system_includes, tool_status, workspace_info,
};
pub use engine::{Engine, engine_start};
pub use error::EngineError;
pub use extract::{
    CrateContext, ExtractError, ItemDoc, Scope, Visibility, extract_crate,
    extract_crate_with_version, extract_source,
};
pub use ffi::*;
pub use highlight::{BufferSession, Context, Lang, Position, Site, SiteAt, scrub_macros};
pub use index::{
    DEPRECATED, Manifest, NAME_HUMP, PARENT_PATH, REACHABLE, SCHEMA_VERSION, hump, last_status,
    live_index_dir, parent_path_of, read_manifest, rebuild_index, write_index,
};
pub use markdown::render as render_markdown;
pub use toolchain::tool_path;
