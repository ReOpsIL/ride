use std::path::{Path, PathBuf};

use crate::error::EngineError;
use crate::ffi::EngineConfig;
use crate::toolchain::{find_tool, tool};

use super::model::{self, ProjectKind, ProjectModel};
use super::{Detect, cmake_api, cmake_targets};

const PROFILES: [&str; 3] = ["Debug", "Release", "RelWithDebInfo"];
const DEFAULT_PROFILE: &str = "Debug";
const MISSING: &str = "cmake is not on PATH: install cmake to list targets for this project";

pub struct CMake;

impl Detect for CMake {
    fn detect(root: &Path, _config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        let Some(mut model) = model::marked(root, ProjectKind::CMake, &["CMakeLists.txt"]) else {
            return Ok(None);
        };
        model.profiles = PROFILES.iter().map(|p| (*p).to_string()).collect();
        if find_tool("cmake").is_none() {
            model.notice = Some(MISSING.to_string());
            return Ok(Some(model));
        }
        match load(root, DEFAULT_PROFILE) {
            Ok(targets) => model.targets = targets,
            Err(notice) => model.notice = Some(notice),
        }
        Ok(Some(model))
    }
}

pub fn build_dir(profile: &str) -> String {
    format!("build/{profile}")
}

fn load(root: &Path, profile: &str) -> Result<Vec<crate::ffi::Target>, String> {
    let build = root.join(build_dir(profile));
    cmake_api::write_query(&build).map_err(|e| e.to_string())?;
    configure(root, &build, profile)?;
    let items = cmake_api::read_targets(&build, profile).map_err(|e| e.to_string())?;
    Ok(cmake_targets::targets(&items, root, &build_dir(profile)))
}

fn configure(root: &Path, build: &PathBuf, profile: &str) -> Result<(), String> {
    let output = tool("cmake")
        .arg("-S")
        .arg(root)
        .arg("-B")
        .arg(build)
        .arg("-DCMAKE_EXPORT_COMPILE_COMMANDS=ON")
        .arg(format!("-DCMAKE_BUILD_TYPE={profile}"))
        .output()
        .map_err(|e| format!("cmake: {e}"))?;
    if output.status.success() {
        return Ok(());
    }
    Err(failure(&output.stderr, &output.stdout))
}

fn failure(stderr: &[u8], stdout: &[u8]) -> String {
    let text = String::from_utf8_lossy(stderr);
    let text = if text.trim().is_empty() {
        String::from_utf8_lossy(stdout).into_owned()
    } else {
        text.into_owned()
    };
    let tail: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
    let start = tail.len().saturating_sub(6);
    format!("cmake configure failed: {}", tail[start..].join(" "))
}
