use std::path::Path;

use crate::error::EngineError;
use crate::extract::Scope;
use crate::ffi::{EngineConfig, WorkspaceInfo};

use super::DiscoveredCrate;
use super::metadata_json::{Metadata, cargo_metadata};
use super::sysroot::{rust_src_available, sysroot_path};

pub struct MetadataResult {
    pub info: WorkspaceInfo,
    pub used_network: bool,
    pub packages: Vec<DiscoveredCrate>,
}

pub fn workspace_info(root: &Path, config: &EngineConfig) -> Result<WorkspaceInfo, EngineError> {
    let sysroot = sysroot_path(config)?;
    let rust_src = rust_src_available(sysroot.as_deref());
    let sysroot_s = sysroot.map(|p| p.display().to_string());
    let manifest = root.join("Cargo.toml");
    if !manifest.is_file() {
        return Ok(WorkspaceInfo {
            root: root.display().to_string(),
            package_name: None,
            is_cargo: false,
            members: Vec::new(),
            rust_src_available: rust_src,
            sysroot: sysroot_s,
        });
    }
    let (meta, _) = cargo_metadata(&manifest, config.offline_metadata, true)?;
    Ok(WorkspaceInfo {
        root: root.display().to_string(),
        package_name: meta
            .packages
            .iter()
            .find(|p| {
                meta.workspace_members.contains(&p.id) && Path::new(&p.manifest_path) == manifest
            })
            .or_else(|| {
                meta.packages
                    .iter()
                    .find(|p| meta.workspace_members.contains(&p.id))
            })
            .map(|p| p.name.clone()),
        is_cargo: true,
        members: meta
            .packages
            .iter()
            .filter(|p| meta.workspace_members.contains(&p.id))
            .map(|p| p.name.clone())
            .collect(),
        rust_src_available: rust_src,
        sysroot: sysroot_s,
    })
}

pub fn load_metadata(root: &Path, config: &EngineConfig) -> Result<MetadataResult, EngineError> {
    let info = workspace_info(root, config)?;
    if !info.is_cargo {
        return Ok(MetadataResult {
            info,
            used_network: false,
            packages: Vec::new(),
        });
    }
    let manifest = root.join("Cargo.toml");
    let (meta, used_network) = cargo_metadata(&manifest, config.offline_metadata, false)?;
    let direct = direct_dep_ids(&meta);
    let mut packages = Vec::new();
    for pkg in &meta.packages {
        let scope = if meta.workspace_members.contains(&pkg.id) {
            Scope::Workspace
        } else if direct.contains(&pkg.id) {
            Scope::DirectDep
        } else {
            Scope::Transitive
        };
        let path = Path::new(&pkg.manifest_path)
            .parent()
            .unwrap_or(Path::new(&pkg.manifest_path))
            .to_path_buf();
        packages.push(DiscoveredCrate {
            name: pkg.name.clone(),
            version: pkg.version.clone(),
            path,
            scope,
        });
    }
    Ok(MetadataResult {
        info,
        used_network,
        packages,
    })
}

fn direct_dep_ids(meta: &Metadata) -> Vec<String> {
    let Some(resolve) = &meta.resolve else {
        return Vec::new();
    };
    let root_id = resolve
        .root
        .clone()
        .or_else(|| meta.workspace_members.first().cloned());
    let Some(root_id) = root_id else {
        return Vec::new();
    };
    resolve
        .nodes
        .iter()
        .find(|n| n.id == root_id)
        .map(|n| n.dependencies.clone())
        .unwrap_or_default()
}

pub struct PackageTargets {
    pub name: String,
    pub targets: Vec<CrateTarget>,
}

pub struct CrateTarget {
    pub name: String,
    pub kinds: Vec<String>,
    pub src_path: String,
}

pub fn workspace_targets(
    manifest: &Path,
    offline: bool,
) -> Result<Vec<PackageTargets>, EngineError> {
    let (meta, _) = cargo_metadata(manifest, offline, true)?;
    Ok(meta
        .packages
        .iter()
        .filter(|pkg| meta.workspace_members.contains(&pkg.id))
        .map(|pkg| PackageTargets {
            name: pkg.name.clone(),
            targets: pkg
                .targets
                .iter()
                .map(|t| CrateTarget {
                    name: t.name.clone(),
                    kinds: t.kind.clone(),
                    src_path: t.src_path.clone(),
                })
                .collect(),
        })
        .collect())
}
