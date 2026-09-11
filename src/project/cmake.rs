use std::path::Path;

use crate::error::EngineError;
use crate::ffi::EngineConfig;

use super::Detect;
use super::model::{self, ProjectKind, ProjectModel};

pub struct CMake;

impl Detect for CMake {
    fn detect(root: &Path, _config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        Ok(model::marked(root, ProjectKind::CMake, &["CMakeLists.txt"]))
    }
}
