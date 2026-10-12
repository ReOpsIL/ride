use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::digest::sha256_hex;
use crate::error::EngineError;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub kind: String,
    pub name: String,
    pub path: String,
    pub passed: bool,
    pub commit: String,
    pub note: String,
}

pub fn append(
    dir: &Path,
    root: &str,
    kind: &str,
    name: &str,
    path: &str,
    passed: bool,
    note: &str,
) -> Result<(), EngineError> {
    fs::create_dir_all(dir).map_err(|err| EngineError::io(dir, err))?;
    let file = dir.join(format!("{}.jsonl", repo_id(root)));
    let commit =
        crate::git::head_commit(&crate::git::require(Path::new(root))?).unwrap_or_default();
    let event = Event {
        kind: kind.to_string(),
        name: name.to_string(),
        path: path.to_string(),
        passed,
        commit,
        note: note.to_string(),
    };
    let line = serde_json::to_string(&event).map_err(|err| EngineError::git(err.to_string()))?;
    let mut file_handle = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&file)
        .map_err(|err| EngineError::io(&file, err))?;
    use std::io::Write;
    writeln!(file_handle, "{line}").map_err(|err| EngineError::io(&file, err))
}

pub fn read(dir: &Path, root: &str) -> Vec<Event> {
    let Ok(text) = fs::read_to_string(dir.join(format!("{}.jsonl", repo_id(root)))) else {
        return Vec::new();
    };
    text.lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect()
}

fn repo_id(root: &str) -> String {
    sha256_hex(&[root.as_bytes()]).chars().take(16).collect()
}
