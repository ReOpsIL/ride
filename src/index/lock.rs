use std::fs::{File, OpenOptions};
use std::path::Path;

use crate::error::EngineError;

pub const LOCK_FILE: &str = ".lock";

pub struct IndexLock {
    _file: File,
}

pub fn acquire(index_dir: &Path) -> Result<IndexLock, EngineError> {
    let path = index_dir.join(LOCK_FILE);
    let file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .open(&path)
        .map_err(|e| EngineError::io(&path, e))?;
    file.lock().map_err(|e| EngineError::io(&path, e))?;
    Ok(IndexLock { _file: file })
}
