use std::collections::HashSet;
use std::path::Path;

use crate::discover::{DiscoveredCrate, Discovery};
use crate::extract::{
    CrateExtract, External, ExtractError, ItemDoc, Scope, extract_crate_parts,
    extract_crate_with_version, plain_extract,
};

use super::hash::crate_key;
use super::labels::scope_rank;

pub fn collect_crates(discovery: &Discovery, project: &Path) -> Vec<DiscoveredCrate> {
    let mut crates = discovery.unpacked.clone();
    if !discovery.workspace.is_cargo {
        crates.push(plain_workspace(project));
    }
    let mut seen = HashSet::new();
    crates.retain(|c| seen.insert(crate_key(&c.path)));
    crates.sort_by(|a, b| {
        scope_rank(a.scope)
            .cmp(&scope_rank(b.scope))
            .then(a.name.cmp(&b.name))
    });
    crates
}

pub fn extract_items(
    crate_: &DiscoveredCrate,
    external: &External,
) -> Result<Vec<ItemDoc>, ExtractError> {
    let version = version_of(crate_);
    match extract_crate_with_version(&crate_.path, crate_.scope, version, external) {
        Ok(items) => Ok(items),
        Err(ExtractError::Toml { .. }) if crate_.scope == Scope::Workspace => {
            super::folder::extract_plain_folder(&crate_.path, crate_.scope)
        }
        Err(e) => Err(e),
    }
}

pub fn extract_parts(crate_: &DiscoveredCrate) -> Result<CrateExtract, ExtractError> {
    match extract_crate_parts(&crate_.path, crate_.scope, version_of(crate_)) {
        Ok(parts) => Ok(parts),
        Err(ExtractError::Toml { .. }) if crate_.scope == Scope::Workspace => {
            let items = super::folder::extract_plain_folder(&crate_.path, crate_.scope)?;
            Ok(plain_extract(items, crate_.name.clone(), crate_.scope))
        }
        Err(e) => Err(e),
    }
}

fn version_of(crate_: &DiscoveredCrate) -> Option<&str> {
    (crate_.scope == Scope::Sysroot).then_some(crate_.version.as_str())
}

fn plain_workspace(project: &Path) -> DiscoveredCrate {
    DiscoveredCrate {
        name: project
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| "workspace".into()),
        version: "0.0.0".into(),
        path: project.to_path_buf(),
        scope: Scope::Workspace,
    }
}
