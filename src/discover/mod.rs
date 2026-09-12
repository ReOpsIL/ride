use std::path::{Path, PathBuf};

use crate::error::EngineError;
use crate::extract::Scope;
use crate::ffi::{EngineConfig, WorkspaceInfo};

mod home;
pub(crate) mod metadata;
mod metadata_json;
mod name_version;
mod registry;
mod sysroot;
pub mod system_includes;
mod tools;

pub use home::cargo_home;
pub use metadata::workspace_info;
pub use sysroot::{rustc_sysroot, sysroot_path};
pub use system_includes::{SystemIncludes, probe_args};
pub use tools::tool_status;

#[derive(Debug, Clone)]
pub struct DiscoveredCrate {
    pub name: String,
    pub version: String,
    pub path: PathBuf,
    pub scope: Scope,
}

#[derive(Debug, Clone)]
pub struct CrateTarball {
    pub file_name: String,
    pub path: PathBuf,
}

#[derive(Debug, Clone)]
pub struct Discovery {
    pub cargo_home: PathBuf,
    pub sysroot: Option<PathBuf>,
    pub rust_src_available: bool,
    pub unpacked: Vec<DiscoveredCrate>,
    pub tarballs: Vec<CrateTarball>,
    pub workspace: WorkspaceInfo,
    pub metadata_used_network: bool,
}

pub fn discover(config: &EngineConfig, project: Option<&Path>) -> Result<Discovery, EngineError> {
    let cargo_home = cargo_home(config);
    let sysroot = sysroot_path(config)?;
    let rust_src_available = sysroot::rust_src_available(sysroot.as_deref());
    let mut unpacked = registry::scan_registry_src(&cargo_home);
    unpacked.extend(registry::scan_git_checkouts(&cargo_home));
    if let Some(sys) = &sysroot {
        unpacked.extend(sysroot::scan_sysroot(sys));
    }
    let tarballs = registry::scan_registry_cache(&cargo_home);
    let (workspace, metadata_used_network, meta_packages) = if let Some(root) = project {
        let loaded = metadata::load_metadata(root, config)?;
        (loaded.info, loaded.used_network, loaded.packages)
    } else {
        (
            WorkspaceInfo {
                root: String::new(),
                package_name: None,
                is_cargo: false,
                members: Vec::new(),
                rust_src_available,
                sysroot: sysroot.as_ref().map(|p| p.display().to_string()),
            },
            false,
            Vec::new(),
        )
    };
    apply_metadata_scopes(&mut unpacked, &meta_packages);
    for pkg in meta_packages {
        if pkg.scope == Scope::Workspace
            && !unpacked
                .iter()
                .any(|c| c.path == pkg.path && c.name == pkg.name)
        {
            unpacked.push(pkg);
        }
    }
    Ok(Discovery {
        cargo_home,
        sysroot,
        rust_src_available,
        unpacked,
        tarballs,
        workspace,
        metadata_used_network,
    })
}

fn apply_metadata_scopes(unpacked: &mut [DiscoveredCrate], meta: &[DiscoveredCrate]) {
    for crate_ in unpacked.iter_mut() {
        if crate_.scope == Scope::Sysroot {
            continue;
        }
        if let Some(found) = meta.iter().find(|m| {
            m.name == crate_.name && (m.version == crate_.version || crate_.scope == Scope::Cache)
        }) && found.scope != Scope::Cache
        {
            crate_.scope = found.scope;
        }
    }
}
