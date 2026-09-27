use std::path::Path;

use crate::error::EngineError;
use crate::extract::Scope;
use crate::ffi::{EngineConfig, WorkspaceInfo};

use super::home::cargo_home;
use super::metadata::load_metadata;
use super::model::{DiscoveredCrate, Discovery};
use super::registry;
use super::scopes::apply_metadata_scopes;
use super::sysroot::{self, sysroot_path};

pub fn discover(config: &EngineConfig, project: Option<&Path>) -> Result<Discovery, EngineError> {
    let sysroot = sysroot_path(config)?;
    let rust_src_available = sysroot::rust_src_available(sysroot.as_deref());
    let mut unpacked = cached_crates(&cargo_home(config), sysroot.as_deref());
    let (workspace, packages) = match project {
        Some(root) => {
            let loaded = load_metadata(root, config)?;
            (loaded.info, loaded.packages)
        }
        None => (
            no_workspace(rust_src_available, sysroot.as_deref()),
            Vec::new(),
        ),
    };
    apply_metadata_scopes(&mut unpacked, &packages);
    for pkg in packages {
        let known = unpacked
            .iter()
            .any(|c| c.path == pkg.path && c.name == pkg.name);
        if pkg.scope == Scope::Workspace && !known {
            unpacked.push(pkg);
        }
    }
    Ok(Discovery {
        rust_src_available,
        unpacked,
        workspace,
    })
}

fn cached_crates(cargo_home: &Path, sysroot: Option<&Path>) -> Vec<DiscoveredCrate> {
    let mut unpacked = registry::scan_registry_src(cargo_home);
    unpacked.extend(registry::scan_git_checkouts(cargo_home));
    if let Some(sys) = sysroot {
        unpacked.extend(sysroot::scan_sysroot(sys));
    }
    unpacked
}

fn no_workspace(rust_src_available: bool, sysroot: Option<&Path>) -> WorkspaceInfo {
    WorkspaceInfo {
        root: String::new(),
        workspace_root: String::new(),
        package_name: None,
        is_cargo: false,
        members: Vec::new(),
        rust_src_available,
        sysroot: sysroot.map(|p| p.display().to_string()),
    }
}
