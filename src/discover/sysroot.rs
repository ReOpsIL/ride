use std::path::{Path, PathBuf};

use crate::error::EngineError;
use crate::extract::Scope;
use crate::ffi::EngineConfig;

use super::DiscoveredCrate;

const SYSROOT_CRATES: [&str; 5] = ["core", "alloc", "std", "proc_macro", "test"];

pub fn sysroot_path(config: &EngineConfig) -> Result<Option<PathBuf>, EngineError> {
    if let Some(path) = &config.sysroot {
        let p = PathBuf::from(path);
        return Ok(if p.is_dir() { Some(p) } else { None });
    }
    rustc_sysroot()
}

pub fn rustc_sysroot() -> Result<Option<PathBuf>, EngineError> {
    let output = crate::toolchain::tool("rustc")
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
    let version = rustc_version().unwrap_or_else(|| "sysroot".into());
    SYSROOT_CRATES
        .iter()
        .map(|name| (name, library.join(name)))
        .filter(|(_, path)| path.join("Cargo.toml").is_file())
        .map(|(name, path)| DiscoveredCrate {
            name: (*name).to_string(),
            version: version.clone(),
            path,
            scope: Scope::Sysroot,
        })
        .collect()
}

fn rustc_version() -> Option<String> {
    let output = crate::toolchain::tool("rustc")
        .arg("--version")
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout);
    text.split_whitespace().nth(1).map(str::to_string)
}
