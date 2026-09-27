use std::collections::HashSet;
use std::path::Path;

use crate::discover::{DiscoveredCrate, Discovery};
use crate::extract::{
    CrateExtract, External, ExtractError, ItemDoc, Scope, extract_crate_parts,
    extract_crate_with_version, plain_extract,
};

use super::folder::extract_plain_folder;
use super::hash::crate_key;

pub fn collect_crates(discovery: &Discovery, project: &Path) -> Vec<DiscoveredCrate> {
    let mut crates = discovery.unpacked.clone();
    if !discovery.workspace.is_cargo {
        crates.push(plain_workspace(project));
    }
    let mut seen = HashSet::new();
    crates.retain(|c| seen.insert(crate_key(&c.path)));
    crates.sort_by(|a, b| {
        build_order(a.scope)
            .cmp(&build_order(b.scope))
            .then(a.name.cmp(&b.name))
    });
    crates
}

fn build_order(scope: Scope) -> u8 {
    match scope {
        Scope::Sysroot => 0,
        Scope::Workspace => 1,
        Scope::DirectDep => 2,
        Scope::Transitive => 3,
        Scope::Cache => 4,
    }
}

pub fn extract_items(
    crate_: &DiscoveredCrate,
    external: &External,
) -> Result<Vec<ItemDoc>, ExtractError> {
    if is_plain_folder(crate_) {
        return extract_plain_folder(&crate_.path, crate_.scope);
    }
    let version = version_of(crate_);
    match extract_crate_with_version(&crate_.path, crate_.scope, version, external) {
        Err(e) if falls_back(crate_, &e) => extract_plain_folder(&crate_.path, crate_.scope),
        other => other,
    }
}

pub fn extract_parts(crate_: &DiscoveredCrate) -> Result<CrateExtract, ExtractError> {
    if is_plain_folder(crate_) {
        return plain_parts(crate_);
    }
    match extract_crate_parts(&crate_.path, crate_.scope, version_of(crate_)) {
        Err(e) if falls_back(crate_, &e) => plain_parts(crate_),
        other => other,
    }
}

fn plain_parts(crate_: &DiscoveredCrate) -> Result<CrateExtract, ExtractError> {
    let items = extract_plain_folder(&crate_.path, crate_.scope)?;
    Ok(plain_extract(items, crate_.name.clone(), crate_.scope))
}

fn is_plain_folder(crate_: &DiscoveredCrate) -> bool {
    crate_.scope == Scope::Workspace && !crate_.path.join("Cargo.toml").is_file()
}

fn falls_back(crate_: &DiscoveredCrate, err: &ExtractError) -> bool {
    crate_.scope == Scope::Workspace && matches!(err, ExtractError::Toml { .. })
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
