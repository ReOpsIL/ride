use std::fs;
use std::path::{Path, PathBuf};

use crate::extract::{Scope, parse_toml, workspace_members};
use crate::skip::skip_dir_name;

use super::name_version::split_name_version;
use super::{CrateTarball, DiscoveredCrate};

pub fn scan_registry_src(cargo_home: &Path) -> Vec<DiscoveredCrate> {
    let src = cargo_home.join("registry/src");
    let Ok(sources) = fs::read_dir(&src) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for source in sources.flatten() {
        let path = source.path();
        if !path.is_dir() {
            continue;
        }
        let Ok(crates) = fs::read_dir(&path) else {
            continue;
        };
        for entry in crates.flatten() {
            let crate_path = entry.path();
            if !crate_path.join("Cargo.toml").is_file() {
                continue;
            }
            let dir_name = entry.file_name().to_string_lossy().to_string();
            let Some((name, version)) = split_name_version(&dir_name) else {
                continue;
            };
            out.push(DiscoveredCrate {
                name,
                version,
                path: crate_path,
                scope: Scope::Cache,
            });
        }
    }
    out
}

pub fn scan_registry_cache(cargo_home: &Path) -> Vec<CrateTarball> {
    let cache = cargo_home.join("registry/cache");
    let Ok(sources) = fs::read_dir(&cache) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for source in sources.flatten() {
        let path = source.path();
        if !path.is_dir() {
            continue;
        }
        let Ok(files) = fs::read_dir(&path) else {
            continue;
        };
        for entry in files.flatten() {
            let file = entry.path();
            if file.extension().and_then(|e| e.to_str()) != Some("crate") {
                continue;
            }
            let file_name = entry.file_name().to_string_lossy().to_string();
            out.push(CrateTarball {
                file_name,
                path: file,
            });
        }
    }
    out
}

pub fn scan_git_checkouts(cargo_home: &Path) -> Vec<DiscoveredCrate> {
    let root = cargo_home.join("git/checkouts");
    let Ok(repos) = fs::read_dir(&root) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for repo in repos.flatten() {
        let repo_path = repo.path();
        if !repo_path.is_dir() {
            continue;
        }
        let Ok(revs) = fs::read_dir(&repo_path) else {
            continue;
        };
        for rev in revs.flatten() {
            let checkout = rev.path();
            if checkout.is_dir() {
                out.extend(crates_in_dir(&checkout));
            }
        }
    }
    out
}

pub fn crates_in_dir(root: &Path) -> Vec<DiscoveredCrate> {
    let manifest_path = root.join("Cargo.toml");
    if !manifest_path.is_file() {
        return Vec::new();
    }
    let Ok(value) = parse_toml(&manifest_path) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    if let Some(pkg) = value.get("package")
        && let Some(name) = pkg.get("name").and_then(|v| v.as_str())
    {
        let version = pkg
            .get("version")
            .and_then(|v| v.as_str())
            .unwrap_or("0.0.0")
            .to_string();
        out.push(DiscoveredCrate {
            name: name.to_string(),
            version,
            path: root.to_path_buf(),
            scope: Scope::Cache,
        });
    }
    for member in workspace_members(&value) {
        for path in expand_member(root, &member) {
            if path == *root {
                continue;
            }
            out.extend(crates_in_dir(&path));
        }
    }
    out
}

fn expand_member(root: &Path, pattern: &str) -> Vec<PathBuf> {
    if let Some((base, rest)) = pattern.split_once('*') {
        let dir = root.join(base.trim_end_matches('/'));
        let Ok(entries) = fs::read_dir(&dir) else {
            return Vec::new();
        };
        return entries
            .flatten()
            .filter_map(|e| {
                let name = e.file_name();
                let name = name.to_string_lossy();
                if skip_dir_name(&name) {
                    return None;
                }
                let path = if rest.is_empty() {
                    e.path()
                } else {
                    e.path().join(rest.trim_start_matches('/'))
                };
                path.is_dir()
                    .then_some(if rest.is_empty() { e.path() } else { path })
            })
            .collect();
    }
    let path = root.join(pattern);
    if path.is_dir() {
        vec![path]
    } else {
        Vec::new()
    }
}
