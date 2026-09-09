use std::fs;
use std::path::{Path, PathBuf};

use crate::error::EngineError;

use super::gc::prune_generations;
use super::status::{Manifest, read_manifest, write_manifest_atomic};

pub fn promote(index_dir: &Path, staging: &Path, manifest: &Manifest) -> Result<(), EngineError> {
    sync_dir(staging);
    let live = index_dir.join(&manifest.live_dir);
    if live.exists() {
        fs::remove_dir_all(&live).map_err(|e| EngineError::io(&live, e))?;
    }
    fs::rename(staging, &live).map_err(|e| EngineError::io(&live, e))?;
    write_manifest_atomic(index_dir, manifest)?;
    prune_generations(index_dir, manifest.generation);
    Ok(())
}

pub fn live_index_dir(index_dir: &Path) -> Option<PathBuf> {
    let manifest = read_manifest(index_dir)?;
    Some(index_dir.join(&manifest.live_dir))
}

pub fn tv(err: tantivy::TantivyError) -> EngineError {
    EngineError::Index {
        message: err.to_string(),
    }
}

fn sync_dir(path: &Path) {
    if let Ok(f) = fs::File::open(path) {
        let _ = f.sync_all();
    }
}
