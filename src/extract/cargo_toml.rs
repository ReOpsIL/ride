use std::fs;
use std::path::{Path, PathBuf};

use super::ExtractError;

#[derive(Debug, Clone)]
pub struct Package {
    pub name: String,
    pub version: String,
    pub edition: Option<String>,
    pub description: Option<String>,
    pub entries: Vec<PathBuf>,
}

pub fn read_package(crate_root: &Path) -> Result<Package, ExtractError> {
    let manifest = crate_root.join("Cargo.toml");
    let text = fs::read_to_string(&manifest).map_err(|source| ExtractError::Io {
        path: manifest.clone(),
        source,
    })?;
    let value: toml::Value = toml::from_str(&text).map_err(|e| ExtractError::Toml {
        path: manifest.clone(),
        message: e.to_string(),
    })?;
    let pkg = value.get("package").ok_or_else(|| ExtractError::Toml {
        path: manifest.clone(),
        message: "missing [package]".into(),
    })?;
    let name = string_field(pkg, "name").ok_or_else(|| ExtractError::Toml {
        path: manifest.clone(),
        message: "missing package.name".into(),
    })?;
    let version = string_field(pkg, "version").unwrap_or_else(|| "0.0.0".into());
    let edition = string_field(pkg, "edition");
    let description = string_field(pkg, "description");
    let entries = entry_points(crate_root, &value);
    Ok(Package {
        name,
        version,
        edition,
        description,
        entries,
    })
}

fn string_field(table: &toml::Value, key: &str) -> Option<String> {
    match table.get(key)? {
        toml::Value::String(s) => Some(s.clone()),
        toml::Value::Table(t) => t.get("value").and_then(|v| v.as_str().map(str::to_string)),
        _ => None,
    }
}

fn entry_points(root: &Path, value: &toml::Value) -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Some(lib) = value.get("lib")
        && let Some(path) = lib.get("path").and_then(|v| v.as_str())
    {
        push_existing(&mut out, root.join(path));
    }
    if let Some(bins) = value.get("bin").and_then(|v| v.as_array()) {
        for bin in bins {
            if let Some(path) = bin.get("path").and_then(|v| v.as_str()) {
                push_existing(&mut out, root.join(path));
            }
        }
    }
    push_existing(&mut out, root.join("src/lib.rs"));
    push_existing(&mut out, root.join("src/main.rs"));
    if let Ok(entries) = fs::read_dir(root.join("src/bin")) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("rs") {
                push_existing(&mut out, path);
            }
        }
    }
    out
}

fn push_existing(out: &mut Vec<PathBuf>, path: PathBuf) {
    if path.is_file() && !out.iter().any(|p| p == &path) {
        out.push(path);
    }
}

pub fn workspace_members(manifest: &toml::Value) -> Vec<String> {
    manifest
        .get("workspace")
        .and_then(|w| w.get("members"))
        .and_then(|m| m.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default()
}

pub fn parse_toml(path: &Path) -> Result<toml::Value, ExtractError> {
    let text = fs::read_to_string(path).map_err(|source| ExtractError::Io {
        path: path.to_path_buf(),
        source,
    })?;
    toml::from_str(&text).map_err(|e| ExtractError::Toml {
        path: path.to_path_buf(),
        message: e.to_string(),
    })
}
