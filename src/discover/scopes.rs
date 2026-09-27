use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use crate::extract::Scope;

use super::metadata_json::Metadata;
use super::model::DiscoveredCrate;

pub fn direct_dep_ids(meta: &Metadata) -> HashSet<&str> {
    let Some(resolve) = &meta.resolve else {
        return HashSet::new();
    };
    resolve
        .nodes
        .iter()
        .filter(|node| meta.workspace_members.contains(&node.id))
        .flat_map(|node| node.dependencies.iter().map(String::as_str))
        .collect()
}

pub fn apply_metadata_scopes(unpacked: &mut [DiscoveredCrate], meta: &[DiscoveredCrate]) {
    let by_dir: HashMap<PathBuf, Scope> = meta
        .iter()
        .filter(|m| m.scope != Scope::Cache)
        .map(|m| (canonical(&m.path), m.scope))
        .collect();
    for crate_ in unpacked.iter_mut().filter(|c| c.scope != Scope::Sysroot) {
        if let Some(scope) = by_dir.get(&canonical(&crate_.path)) {
            crate_.scope = *scope;
        }
    }
}

fn canonical(path: &Path) -> PathBuf {
    path.canonicalize().unwrap_or_else(|_| path.to_path_buf())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn crate_at(name: &str, version: &str, path: &str, scope: Scope) -> DiscoveredCrate {
        DiscoveredCrate {
            name: name.into(),
            version: version.into(),
            path: PathBuf::from(path),
            scope,
        }
    }

    #[test]
    fn only_the_resolved_version_takes_the_dependency_scope() {
        let mut unpacked = vec![
            crate_at("serde", "1.0.1", "/reg/serde-1.0.1", Scope::Cache),
            crate_at("serde", "1.0.2", "/reg/serde-1.0.2", Scope::Cache),
        ];
        let meta = vec![crate_at(
            "serde",
            "1.0.2",
            "/reg/serde-1.0.2",
            Scope::DirectDep,
        )];
        apply_metadata_scopes(&mut unpacked, &meta);
        assert_eq!(unpacked[0].scope, Scope::Cache);
        assert_eq!(unpacked[1].scope, Scope::DirectDep);
    }

    #[test]
    fn every_workspace_member_contributes_direct_deps() {
        let json = r#"{
            "packages": [],
            "workspace_members": ["a", "b"],
            "workspace_root": "/ws",
            "resolve": {"nodes": [
                {"id": "a", "dependencies": ["x"]},
                {"id": "b", "dependencies": ["y"]},
                {"id": "x", "dependencies": ["z"]}
            ], "root": null}
        }"#;
        let meta: Metadata = serde_json::from_str(json).unwrap();
        let direct = direct_dep_ids(&meta);
        assert_eq!(direct, HashSet::from(["x", "y"]));
    }
}
