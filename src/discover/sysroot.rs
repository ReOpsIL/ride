use std::path::{Path, PathBuf};
use std::process::Command;

use crate::error::EngineError;
use crate::extract::Scope;
use crate::ffi::EngineConfig;

use super::DiscoveredCrate;

pub fn sysroot_path(config: &EngineConfig) -> Result<Option<PathBuf>, EngineError> {
    if let Some(path) = &config.sysroot {
        let p = PathBuf::from(path);
        return Ok(if p.is_dir() { Some(p) } else { None });
    }
    let output = Command::new("rustc")
        .args(["--print", "sysroot"])
        .output()
        .map_err(|e| EngineError::Metadata {
            message: format!("rustc --print sysroot: {e}"),
        })?;
    if !output.status.success() {
        return Ok(None);
    }
    let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if path.is_empty() {
        return Ok(None);
    }
    let p = PathBuf::from(path);
    Ok(if p.is_dir() { Some(p) } else { None })
}

pub fn rust_src_library(sysroot: &Path) -> PathBuf {
    sysroot.join("lib/rustlib/src/rust/library")
}

pub fn rust_src_available(sysroot: Option<&Path>) -> bool {
    sysroot
        .map(|s| rust_src_library(s).join("std").is_dir())
        .unwrap_or(false)
}

pub fn scan_sysroot(sysroot: &Path) -> Vec<DiscoveredCrate> {
    let library = rust_src_library(sysroot);
    let Ok(entries) = std::fs::read_dir(&library) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        if !path.join("Cargo.toml").is_file() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        if name.ends_with("tests") || name.starts_with("rustc-std-workspace") {
            continue;
        }
        out.push(DiscoveredCrate {
            name,
            version: "sysroot".into(),
            path,
            scope: Scope::Sysroot,
        });
    }
    out
}
