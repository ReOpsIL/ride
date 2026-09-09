use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

use tantivy::{Index, IndexWriter};

use crate::discover::{DiscoveredCrate, discover};
use crate::error::EngineError;
use crate::extract::{ExtractError, Scope, extract_crate};
use crate::ffi::{EngineConfig, IndexState, IndexStatus};

use super::doc::{keep_item, to_document};
use super::hash::{content_hash, crate_key};
use super::schema::build_fields;
use super::status::{Manifest, append_status, read_manifest, write_manifest_atomic};

const WRITER_MEMORY: usize = 32 * 1024 * 1024;

pub fn write_index(
    project: &Path,
    index_dir: &Path,
    config: &EngineConfig,
) -> Result<IndexStatus, EngineError> {
    fs::create_dir_all(index_dir).map_err(|e| EngineError::io(index_dir, e))?;
    clean_stagings(index_dir);
    let discovery = discover(config, Some(project))?;
    let mut crates = discovery.unpacked;
    if !discovery.workspace.is_cargo {
        crates.push(DiscoveredCrate {
            name: project
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| "workspace".into()),
            version: "0.0.0".into(),
            path: project.to_path_buf(),
            scope: Scope::Workspace,
        });
    }
    crates.sort_by(|a, b| {
        scope_rank(a.scope)
            .cmp(&scope_rank(b.scope))
            .then(a.name.cmp(&b.name))
    });
    let crates_total = crates.len() as u32;
    let mut status = IndexStatus {
        state: IndexState::Indexing,
        docs: 0,
        crates_done: 0,
        crates_total,
        rust_src_available: discovery.rust_src_available,
        message: Some("indexing".into()),
    };
    append_status(index_dir, &status)?;
    let prev = read_manifest(index_dir);
    let generation = prev.as_ref().map(|m| m.generation + 1).unwrap_or(1);
    let staging = index_dir.join(format!("staging-{}", std::process::id()));
    if staging.exists() {
        fs::remove_dir_all(&staging).map_err(|e| EngineError::io(&staging, e))?;
    }
    fs::create_dir_all(&staging).map_err(|e| EngineError::io(&staging, e))?;
    let fields = build_fields();
    let index = Index::create_in_dir(&staging, fields.schema.clone()).map_err(tv)?;
    let mut writer: IndexWriter = index.writer(WRITER_MEMORY).map_err(tv)?;
    let mut seen = HashSet::new();
    let mut docs = 0u32;
    for crate_ in &crates {
        let key = crate_key(&crate_.path);
        if !seen.insert(key) {
            continue;
        }
        match extract_items(crate_) {
            Ok(items) => {
                let hash = content_hash(&crate_.path);
                for item in items.iter().filter(|i| keep_item(i)) {
                    writer
                        .add_document(to_document(&fields, item, &hash))
                        .map_err(tv)?;
                    docs += 1;
                }
            }
            Err(e) => {
                status.message = Some(format!("{}: {e}", crate_.name));
            }
        }
        status.crates_done += 1;
        status.docs = docs;
        append_status(index_dir, &status)?;
    }
    writer.commit().map_err(tv)?;
    writer.wait_merging_threads().map_err(tv)?;
    drop(index);
    sync_dir(&staging);
    let live = index_dir.join(format!("gen-{generation}"));
    if live.exists() {
        fs::remove_dir_all(&live).map_err(|e| EngineError::io(&live, e))?;
    }
    let manifest = Manifest::next(prev.as_ref(), generation);
    fs::rename(&staging, &live).map_err(|e| EngineError::io(&live, e))?;
    write_manifest_atomic(index_dir, &manifest)?;
    status.state = IndexState::Ready;
    status.docs = docs;
    status.message = None;
    append_status(index_dir, &status)?;
    Ok(status)
}

fn extract_items(crate_: &DiscoveredCrate) -> Result<Vec<crate::extract::ItemDoc>, ExtractError> {
    match extract_crate(&crate_.path, crate_.scope) {
        Ok(items) => Ok(items),
        Err(ExtractError::Toml { .. }) if crate_.scope == Scope::Workspace => {
            super::folder::extract_plain_folder(&crate_.path, crate_.scope)
        }
        Err(e) => Err(e),
    }
}

fn scope_rank(scope: Scope) -> u8 {
    match scope {
        Scope::Workspace => 0,
        Scope::Sysroot => 1,
        Scope::DirectDep => 2,
        Scope::Transitive => 3,
        Scope::Cache => 4,
    }
}

fn clean_stagings(index_dir: &Path) {
    let Ok(entries) = fs::read_dir(index_dir) else {
        return;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        if name.to_string_lossy().starts_with("staging-") {
            let _ = fs::remove_dir_all(entry.path());
        }
    }
}

fn sync_dir(path: &Path) {
    if let Ok(f) = fs::File::open(path) {
        let _ = f.sync_all();
    }
}

fn tv(err: tantivy::TantivyError) -> EngineError {
    EngineError::Index {
        message: err.to_string(),
    }
}

pub fn live_index_dir(index_dir: &Path) -> Option<PathBuf> {
    let manifest = read_manifest(index_dir)?;
    Some(index_dir.join(&manifest.live_dir))
}
