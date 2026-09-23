use std::path::Path;
use std::thread;

use crate::error::EngineError;
use crate::ffi::ProjectModel;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn project_model(&self, root: String) -> Result<ProjectModel, EngineError> {
        self.guard(|| load(self, &root, false))
    }

    pub fn reload_project(&self, root: String) -> Result<ProjectModel, EngineError> {
        self.guard(|| load(self, &root, true))
    }

    pub fn workspace_projects(&self, root: String) -> Result<Vec<ProjectModel>, EngineError> {
        self.guard(|| load_all(self, Path::new(&root), false))
    }

    pub fn reload_workspace_projects(
        &self,
        root: String,
    ) -> Result<Vec<ProjectModel>, EngineError> {
        self.guard(|| load_all(self, Path::new(&root), true))
    }
}

fn load_all(engine: &Engine, root: &Path, force: bool) -> Result<Vec<ProjectModel>, EngineError> {
    let roots = crate::project::project_roots(root);
    if roots.is_empty() {
        return Ok(vec![load(engine, &root.display().to_string(), force)?]);
    }
    Ok(thread::scope(|scope| {
        let jobs: Vec<_> = roots
            .iter()
            .map(|dir| scope.spawn(move || detected(engine, dir, force)))
            .collect();
        jobs.into_iter()
            .zip(&roots)
            .map(|(job, dir)| {
                job.join()
                    .unwrap_or_else(|payload| failed(dir, EngineError::from_panic(payload)))
            })
            .collect()
    }))
}

fn detected(engine: &Engine, dir: &Path, force: bool) -> ProjectModel {
    load(engine, &dir.display().to_string(), force).unwrap_or_else(|error| failed(dir, error))
}

fn failed(dir: &Path, error: EngineError) -> ProjectModel {
    crate::project::unreadable(dir, error.to_string())
}

fn load(engine: &Engine, root: &str, force: bool) -> Result<ProjectModel, EngineError> {
    if force {
        engine.forget_cargo_roots();
    }
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
