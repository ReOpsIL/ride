uniffi::setup_scaffolding!();

mod check;
mod discover;
mod engine;
mod error;
mod extract;
mod ffi;
mod highlight;
mod index;
mod markdown;
mod query;
mod skip;
mod toolchain;

pub use check::{format_source, parse_lines, run_check};
pub use discover::{
    CrateTarball, DiscoveredCrate, Discovery, cargo_home, discover, sysroot_path, workspace_info,
};
pub use engine::{Engine, engine_start};
pub use error::EngineError;
pub use extract::{
    CrateContext, ExtractError, ItemDoc, Scope, Visibility, extract_crate,
    extract_crate_with_version, extract_source,
};
pub use ffi::*;
pub use highlight::{BufferSession, Lang};
pub use index::{
    Manifest, SCHEMA_VERSION, last_status, live_index_dir, read_manifest, rebuild_index,
    write_index,
};
pub use markdown::render as render_markdown;
pub use toolchain::tool_path;
