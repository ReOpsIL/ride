use std::path::Path;

use crate::error::EngineError;
use crate::ffi::EngineConfig;

use super::Detect;
use super::model::{self, ProjectKind, ProjectModel};

pub struct Cargo;

impl Detect for Cargo {
    fn detect(root: &Path, _config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        Ok(model::marked(root, ProjectKind::Cargo, &["Cargo.toml"]))
    }
}
