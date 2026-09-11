mod cargo;
mod cmake;
mod compile_db;
mod make;
mod model;

use std::path::Path;

use crate::error::EngineError;
use crate::ffi::EngineConfig;

use self::model::ProjectModel;

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
    Ok(model::unmatched(root))
}
