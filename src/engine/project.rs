use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::error::EngineError;
use crate::ffi::ProjectModel;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn project_model(&self, root: String) -> Result<ProjectModel, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| load(self, &root, false))) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn reload_project(&self, root: String) -> Result<ProjectModel, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| load(self, &root, true))) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }
}

fn load(engine: &Engine, root: &str, force: bool) -> Result<ProjectModel, EngineError> {
    if !force && let Some(model) = engine.read(|i| i.projects.get(root).cloned())? {
        return Ok(model);
    }
    let config = engine.read(|i| i.config.clone())?;
    let model = crate::project::detect(Path::new(root), &config)?;
    engine.write(|i| {
        i.projects.insert(root.to_string(), model.clone());
    })?;
    Ok(model)
}
