use std::collections::HashSet;
use std::path::Path;

use crate::discover::{DiscoveredCrate, Discovery};
use crate::extract::{ExtractError, ItemDoc, Scope, extract_crate_with_version};

use super::hash::crate_key;

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

pub fn extract_items(crate_: &DiscoveredCrate) -> Result<Vec<ItemDoc>, ExtractError> {
    let version = (crate_.scope == Scope::Sysroot).then_some(crate_.version.as_str());
    match extract_crate_with_version(&crate_.path, crate_.scope, version) {
        Ok(items) => Ok(items),
        Err(ExtractError::Toml { .. }) if crate_.scope == Scope::Workspace => {
            super::folder::extract_plain_folder(&crate_.path, crate_.scope)
        }
        Err(e) => Err(e),
    }
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

fn scope_rank(scope: Scope) -> u8 {
    match scope {
        Scope::Workspace => 0,
        Scope::Sysroot => 1,
        Scope::DirectDep => 2,
        Scope::Transitive => 3,
        Scope::Cache => 4,
    }
}
