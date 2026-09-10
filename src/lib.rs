uniffi::setup_scaffolding!();

mod check;
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
mod query;
mod score;
mod skip;
mod toolchain;

pub use check::{
    format_clang, format_source, include_dirs, parse_clang, parse_lines, run_check, run_clang_check,
};
pub use discover::{
    CrateTarball, DiscoveredCrate, Discovery, SystemIncludes, cargo_home, discover, probe_args,
    sysroot_path, system_includes, workspace_info,
};
pub use engine::{Engine, engine_start};
pub use error::EngineError;
pub use extract::{
    CrateContext, ExtractError, ItemDoc, Scope, Visibility, extract_crate,
    extract_crate_with_version, extract_source,
};
pub use ffi::*;
pub use highlight::{BufferSession, Lang, Position, Site, SiteAt};
pub use index::{
    DEPRECATED, Manifest, NAME_HUMP, PARENT_PATH, REACHABLE, SCHEMA_VERSION, hump, last_status,
    live_index_dir, parent_path_of, read_manifest, rebuild_index, write_index,
};
pub use markdown::render as render_markdown;
pub use toolchain::tool_path;
