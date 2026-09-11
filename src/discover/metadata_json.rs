use std::path::Path;

use serde::Deserialize;

use crate::error::EngineError;

#[derive(Debug, Deserialize)]
pub struct Metadata {
    pub packages: Vec<MetaPackage>,
    pub workspace_members: Vec<String>,
    pub resolve: Option<Resolve>,
}

#[derive(Debug, Deserialize)]
pub struct MetaPackage {
    pub name: String,
    pub version: String,
    pub id: String,
    pub manifest_path: String,
    #[serde(default)]
    pub targets: Vec<MetaTarget>,
}

#[derive(Debug, Deserialize)]
pub struct MetaTarget {
    pub name: String,
    pub kind: Vec<String>,
    pub src_path: String,
}

#[derive(Debug, Deserialize)]
pub struct Resolve {
    pub nodes: Vec<ResolveNode>,
    pub root: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ResolveNode {
    pub id: String,
    pub dependencies: Vec<String>,
}

pub fn cargo_metadata(
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
