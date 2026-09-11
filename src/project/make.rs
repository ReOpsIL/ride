use std::path::Path;

use crate::error::EngineError;
use crate::ffi::EngineConfig;

use super::Detect;
use super::model::{self, ProjectKind, ProjectModel};

pub struct Make;

impl Detect for Make {
    fn detect(root: &Path, _config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        Ok(model::marked(
            root,
            ProjectKind::Make,
            &["Makefile", "GNUmakefile"],
        ))
    }
}
