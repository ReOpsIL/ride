use std::path::PathBuf;

use crate::extract::Scope;
use crate::ffi::WorkspaceInfo;

#[derive(Debug, Clone)]
pub struct DiscoveredCrate {
    pub name: String,
    pub version: String,
    pub path: PathBuf,
    pub scope: Scope,
}

#[derive(Debug, Clone)]
pub struct Discovery {
    pub rust_src_available: bool,
    pub unpacked: Vec<DiscoveredCrate>,
    pub workspace: WorkspaceInfo,
}
