use std::path::Path;

use serde::Deserialize;

use crate::error::EngineError;
use crate::extract::Scope;
use crate::ffi::{EngineConfig, WorkspaceInfo};

use super::DiscoveredCrate;
use super::sysroot::{rust_src_available, sysroot_path};

#[derive(Debug, Deserialize)]
struct Metadata {
    packages: Vec<MetaPackage>,
    workspace_members: Vec<String>,
    resolve: Option<Resolve>,
}

#[derive(Debug, Deserialize)]
struct MetaPackage {
    name: String,
    version: String,
    id: String,
    manifest_path: String,
}

#[derive(Debug, Deserialize)]
struct Resolve {
    nodes: Vec<ResolveNode>,
    root: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ResolveNode {
    id: String,
    dependencies: Vec<String>,
}

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

fn cargo_metadata(
    manifest: &Path,
    offline: bool,
    no_deps: bool,
) -> Result<(Metadata, bool), EngineError> {
    match run_cargo_metadata(manifest, offline, no_deps) {
        Ok(meta) => Ok((meta, false)),
        Err(e) if offline => {
            let meta = run_cargo_metadata(manifest, false, no_deps)?;
            let _ = e;
            Ok((meta, true))
        }
        Err(e) => Err(e),
    }
}

fn run_cargo_metadata(
    manifest: &Path,
    offline: bool,
    no_deps: bool,
) -> Result<Metadata, EngineError> {
    let mut cmd = crate::toolchain::tool("cargo");
    cmd.args(["metadata", "--format-version", "1", "--manifest-path"])
        .arg(manifest);
    if offline {
        cmd.arg("--offline");
    }
    if no_deps {
        cmd.arg("--no-deps");
    }
    let output = cmd.output().map_err(|e| EngineError::Metadata {
        message: format!("cargo metadata: {e}"),
    })?;
    if !output.status.success() {
        return Err(EngineError::Metadata {
            message: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }
    serde_json::from_slice(&output.stdout).map_err(|e| EngineError::Metadata {
        message: format!("parse cargo metadata: {e}"),
    })
}
