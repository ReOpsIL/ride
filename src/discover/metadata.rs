use std::path::Path;

use crate::error::EngineError;
use crate::extract::Scope;
use crate::ffi::{EngineConfig, WorkspaceInfo};

use super::metadata_json::{MetaPackage, Metadata, cargo_metadata};
use super::model::DiscoveredCrate;
use super::scopes::direct_dep_ids;
use super::sysroot::{rust_src_available, sysroot_path};

pub struct MetadataResult {
    pub info: WorkspaceInfo,
    pub packages: Vec<DiscoveredCrate>,
}

struct Toolchain {
    rust_src: bool,
    sysroot: Option<String>,
}

pub fn workspace_info(root: &Path, config: &EngineConfig) -> Result<WorkspaceInfo, EngineError> {
    Ok(inspect(root, config, true)?.info)
}

pub fn load_metadata(root: &Path, config: &EngineConfig) -> Result<MetadataResult, EngineError> {
    inspect(root, config, false)
}

fn inspect(
    root: &Path,
    config: &EngineConfig,
    no_deps: bool,
) -> Result<MetadataResult, EngineError> {
    let sysroot = sysroot_path(config)?;
    let toolchain = Toolchain {
        rust_src: rust_src_available(sysroot.as_deref()),
        sysroot: sysroot.map(|p| p.display().to_string()),
    };
    let manifest = root.join("Cargo.toml");
    if !manifest.is_file() {
        return Ok(MetadataResult {
            info: plain_info(root, toolchain),
            packages: Vec::new(),
        });
    }
    let meta = cargo_metadata(&manifest, config.offline_metadata, no_deps)?;
    Ok(MetadataResult {
        info: cargo_info(root, &manifest, &meta, toolchain),
        packages: if no_deps { Vec::new() } else { packages(&meta) },
    })
}

fn plain_info(root: &Path, toolchain: Toolchain) -> WorkspaceInfo {
    WorkspaceInfo {
        root: root.display().to_string(),
        workspace_root: root.display().to_string(),
        package_name: None,
        is_cargo: false,
        members: Vec::new(),
        rust_src_available: toolchain.rust_src,
        sysroot: toolchain.sysroot,
    }
}

fn cargo_info(
    root: &Path,
    manifest: &Path,
    meta: &Metadata,
    toolchain: Toolchain,
) -> WorkspaceInfo {
    let members: Vec<&MetaPackage> = meta
        .packages
        .iter()
        .filter(|p| meta.workspace_members.contains(&p.id))
        .collect();
    let own = members
        .iter()
        .find(|p| Path::new(&p.manifest_path) == manifest)
        .or_else(|| members.first());
    WorkspaceInfo {
        root: root.display().to_string(),
        workspace_root: meta.workspace_root.clone(),
        package_name: own.map(|p| p.name.clone()),
        is_cargo: true,
        members: members.iter().map(|p| p.name.clone()).collect(),
        rust_src_available: toolchain.rust_src,
        sysroot: toolchain.sysroot,
    }
}

fn packages(meta: &Metadata) -> Vec<DiscoveredCrate> {
    let direct = direct_dep_ids(meta);
    meta.packages
        .iter()
        .map(|pkg| {
            let scope = if meta.workspace_members.contains(&pkg.id) {
                Scope::Workspace
            } else if direct.contains(pkg.id.as_str()) {
                Scope::DirectDep
            } else {
                Scope::Transitive
            };
            let manifest = Path::new(&pkg.manifest_path);
            DiscoveredCrate {
                name: pkg.name.clone(),
                version: pkg.version.clone(),
                path: manifest.parent().unwrap_or(manifest).to_path_buf(),
                scope,
            }
        })
        .collect()
}
