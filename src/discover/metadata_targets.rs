use std::path::Path;

use crate::error::EngineError;

use super::metadata_json::cargo_metadata;

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
    let meta = cargo_metadata(manifest, offline, true)?;
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
