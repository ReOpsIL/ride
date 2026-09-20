use std::fs;
use std::path::Path;

use crate::abspath;
use crate::check::Entry;
use crate::error::EngineError;
use crate::ffi::{EngineConfig, Target, TargetKind};

use super::Detect;
use super::model::{ProjectKind, ProjectModel};

const DB_NAMES: [&str; 2] = ["compile_commands.json", "build/compile_commands.json"];
const UNREADABLE: &str = "compile_commands.json could not be parsed: no targets listed";

pub struct CompileDb;

impl Detect for CompileDb {
    fn detect(root: &Path, _config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        let Some(db) = DB_NAMES
            .iter()
            .map(|name| root.join(name))
            .find(|path| path.is_file())
        else {
            return Ok(None);
        };
        let text = fs::read_to_string(&db).map_err(|e| EngineError::io(&db, e))?;
        let mut model = ProjectModel {
            root: root.display().to_string(),
            kind: ProjectKind::CompileDb,
            targets: Vec::new(),
            profiles: Vec::new(),
            manifest: db.display().to_string(),
            notice: None,
        };
        match serde_json::from_str::<Vec<Entry>>(&text) {
            Ok(entries) => model.targets = targets(root, &db, &entries),
            Err(_) => model.notice = Some(UNREADABLE.to_string()),
        }
        Ok(Some(model))
    }
}

fn targets(root: &Path, db: &Path, entries: &[Entry]) -> Vec<Target> {
    let base = db.parent().unwrap_or(root);
    let mut out: Vec<Target> = Vec::new();
    for entry in entries {
        let dir = abspath::absolute(base, Path::new(&entry.directory));
        let source = abspath::absolute(&dir, Path::new(&entry.file));
        let name = display_name(root, &source);
        if out.iter().any(|t| t.name == name) {
            continue;
        }
        out.push(Target {
            name,
            kind: TargetKind::Custom,
            build: entry.argv().unwrap_or_default(),
            run: None,
            sources: vec![source.display().to_string()],
            working_dir: dir.display().to_string(),
        });
    }
    out
}

fn display_name(root: &Path, source: &Path) -> String {
    source
        .strip_prefix(root)
        .unwrap_or(source)
        .display()
        .to_string()
}
