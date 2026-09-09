use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::Path;

use serde::Serialize;

use crate::error::EngineError;

const FILE: &str = "warnings.jsonl";

#[derive(Serialize)]
struct WarningLine<'a> {
    crate_name: &'a str,
    message: String,
}

pub fn reset_warnings(index_dir: &Path) -> Result<(), EngineError> {
    let path = index_dir.join(FILE);
    fs::write(&path, b"").map_err(|e| EngineError::io(&path, e))
}

pub fn append_warning(
    index_dir: &Path,
    crate_name: &str,
    error: &impl std::fmt::Display,
) -> Result<(), EngineError> {
    let path = index_dir.join(FILE);
    let line = WarningLine {
        crate_name,
        message: error.to_string(),
    };
    let mut json = serde_json::to_string(&line).map_err(|e| EngineError::Index {
        message: e.to_string(),
    })?;
    json.push('\n');
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|e| EngineError::io(&path, e))?;
    file.write_all(json.as_bytes())
        .map_err(|e| EngineError::io(&path, e))
}
