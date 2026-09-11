mod sources;

use std::fs;
use std::path::{Path, PathBuf};

use crate::error::EngineError;
use crate::ffi::{EngineConfig, ItemKind, Target, TargetKind};
use crate::highlight::summarize;

use super::Detect;
use super::model::{ProjectKind, ProjectModel};

const MAKEFILES: [&str; 2] = ["Makefile", "GNUmakefile"];

pub struct Make;

impl Detect for Make {
    fn detect(root: &Path, _config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        if root.join("Cargo.toml").is_file() {
            return Ok(None);
        }
        let Some(manifest) = manifest(root) else {
            return Ok(None);
        };
        let text = fs::read_to_string(&manifest).map_err(|e| EngineError::io(&manifest, e))?;
        let names = rule_names(&manifest, &text)?;
        let has_run = names.iter().any(|name| name == "run");
        let targets = names
            .iter()
            .map(|name| target(root, name, has_run))
            .collect();
        Ok(Some(ProjectModel {
            root: root.display().to_string(),
            kind: ProjectKind::Make,
            targets,
            profiles: vec!["default".to_string()],
            manifest: manifest.display().to_string(),
            notice: None,
        }))
    }
}

fn manifest(root: &Path) -> Option<PathBuf> {
    MAKEFILES
        .iter()
        .map(|name| root.join(name))
        .find(|path| path.is_file())
}

fn target(root: &Path, name: &str, has_run: bool) -> Target {
    Target {
        name: name.to_string(),
        kind: TargetKind::Custom,
        build: vec!["make".to_string(), name.to_string()],
        run: has_run.then(|| vec!["make".to_string(), "run".to_string()]),
        sources: sources::of(root, name),
        working_dir: root.display().to_string(),
    }
}

fn rule_names(manifest: &Path, text: &str) -> Result<Vec<String>, EngineError> {
    let rules: Vec<(String, String)> = summarize(manifest, text)?
        .outline
        .into_iter()
        .filter(|item| item.kind == ItemKind::Target)
        .map(|item| (item.name, item.signature))
        .collect();
    let wanted = prerequisites_of_all(&rules);
    let mut names: Vec<String> = Vec::new();
    for (name, _) in &rules {
        if keep(name, &wanted) && !names.contains(name) {
            names.push(name.clone());
        }
    }
    Ok(names)
}

fn keep(name: &str, wanted: &[String]) -> bool {
    if name.starts_with('.') || name.contains('%') || name.contains('$') {
        return false;
    }
    !name.contains('/') || wanted.iter().any(|prerequisite| prerequisite == name)
}

fn prerequisites_of_all(rules: &[(String, String)]) -> Vec<String> {
    rules
        .iter()
        .filter(|(name, _)| name == "all")
        .filter_map(|(_, signature)| signature.split_once(':'))
        .flat_map(|(_, rest)| rest.split_whitespace().map(str::to_string))
        .collect()
}
