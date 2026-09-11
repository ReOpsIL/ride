use std::path::Path;

use crate::error::EngineError;
use crate::ffi::EngineConfig;

use super::Detect;
use super::model::{self, ProjectKind, ProjectModel};

pub struct CompileDb;

impl Detect for CompileDb {
    fn detect(root: &Path, _config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        Ok(model::marked(
            root,
            ProjectKind::CompileDb,
            &["compile_commands.json", "build/compile_commands.json"],
        ))
    }
}
