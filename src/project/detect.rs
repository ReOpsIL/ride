use std::path::Path;

use crate::error::EngineError;
use crate::ffi::EngineConfig;

use super::model::{self, ProjectModel};
use super::{cargo, cmake, compile_db, make};

pub trait Detect {
    fn detect(root: &Path, config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError>;
}

pub fn detect(root: &Path, config: &EngineConfig) -> Result<ProjectModel, EngineError> {
    if let Some(model) = cargo::Cargo::detect(root, config)? {
        return Ok(model);
    }
    if let Some(model) = cmake::CMake::detect(root, config)? {
        return Ok(model);
    }
    if let Some(model) = make::Make::detect(root, config)? {
        return Ok(model);
    }
    if let Some(model) = compile_db::CompileDb::detect(root, config)? {
        return Ok(model);
    }
    if let Some(model) = cmake::without_cmake(root) {
        return Ok(model);
    }
    Ok(model::unmatched(root))
}
