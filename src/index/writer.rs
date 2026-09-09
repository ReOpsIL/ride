use std::fs;
use std::path::Path;

use tantivy::{Index, IndexWriter};

use crate::discover::discover;
use crate::error::EngineError;
use crate::ffi::{EngineConfig, IndexState, IndexStatus};

use super::crates::{collect_crates, extract_items};
use super::doc::{keep_item, to_document};
use super::fingerprint::{HashedCrate, fingerprint, hash_crates};
use super::gc::clean_stagings;
use super::promote::{promote, tv};
use super::schema::{SCHEMA_VERSION, build_fields};
use super::status::{Manifest, append_status, read_manifest};
use super::warnings::{append_warning, reset_warnings};

const WRITER_MEMORY: usize = 32 * 1024 * 1024;

pub fn write_index(
    project: &Path,
    index_dir: &Path,
    config: &EngineConfig,
) -> Result<IndexStatus, EngineError> {
    run(project, index_dir, config, false)
}

pub fn rebuild_index(
    project: &Path,
    index_dir: &Path,
    config: &EngineConfig,
) -> Result<IndexStatus, EngineError> {
    run(project, index_dir, config, true)
}

fn run(
    project: &Path,
    index_dir: &Path,
    config: &EngineConfig,
    force: bool,
) -> Result<IndexStatus, EngineError> {
    fs::create_dir_all(index_dir).map_err(|e| EngineError::io(index_dir, e))?;
    clean_stagings(index_dir);
    let discovery = discover(config, Some(project))?;
    let crates = collect_crates(&discovery, project);
    let mut status = IndexStatus {
        state: IndexState::Indexing,
        docs: 0,
        crates_done: 0,
        crates_total: crates.len() as u32,
        rust_src_available: discovery.rust_src_available,
        warnings: 0,
        message: Some("indexing".into()),
    };
    append_status(index_dir, &status)?;
    let hashed = hash_crates(crates);
    let fp = fingerprint(&hashed);
    let prev = read_manifest(index_dir);
    if !force && let Some(fresh) = prev.as_ref().filter(|m| is_fresh(m, index_dir, &fp)) {
        return finish(index_dir, status, fresh.docs);
    }
    match build(index_dir, &hashed, &mut status) {
        Ok(docs) => {
            let generation = prev.as_ref().map(|m| m.generation + 1).unwrap_or(1);
            let manifest = Manifest::next(generation, fp, docs);
            promote(index_dir, &staging_dir(index_dir), &manifest)?;
            finish(index_dir, status, docs)
        }
        Err(e) => {
            status.state = IndexState::Error;
            status.message = Some(e.to_string());
            append_status(index_dir, &status)?;
            Err(e)
        }
    }
}

fn build(
    index_dir: &Path,
    hashed: &[HashedCrate],
    status: &mut IndexStatus,
) -> Result<u32, EngineError> {
    reset_warnings(index_dir)?;
    let staging = staging_dir(index_dir);
    if staging.exists() {
        fs::remove_dir_all(&staging).map_err(|e| EngineError::io(&staging, e))?;
    }
    fs::create_dir_all(&staging).map_err(|e| EngineError::io(&staging, e))?;
    let fields = build_fields();
    let index = Index::create_in_dir(&staging, fields.schema.clone()).map_err(tv)?;
    super::tokenizers::register(&index).map_err(tv)?;
    let mut writer: IndexWriter = index.writer(WRITER_MEMORY).map_err(tv)?;
    let mut docs = 0u32;
    for h in hashed {
        match extract_items(&h.crate_) {
            Ok(items) => {
                for item in items.iter().filter(|i| keep_item(i)) {
                    writer
                        .add_document(to_document(&fields, item, &h.hash))
                        .map_err(tv)?;
                    docs += 1;
                }
            }
            Err(e) => {
                append_warning(index_dir, &h.crate_.name, &e)?;
                status.warnings += 1;
            }
        }
        status.crates_done += 1;
        status.docs = docs;
        append_status(index_dir, status)?;
    }
    writer.commit().map_err(tv)?;
    writer.wait_merging_threads().map_err(tv)?;
    Ok(docs)
}

fn finish(
    index_dir: &Path,
    mut status: IndexStatus,
    docs: u32,
) -> Result<IndexStatus, EngineError> {
    status.state = IndexState::Ready;
    status.crates_done = status.crates_total;
    status.docs = docs;
    status.message = None;
    append_status(index_dir, &status)?;
    Ok(status)
}

fn is_fresh(manifest: &Manifest, index_dir: &Path, fp: &str) -> bool {
    manifest.schema_version == SCHEMA_VERSION
        && manifest.fingerprint == fp
        && index_dir.join(&manifest.live_dir).is_dir()
}

fn staging_dir(index_dir: &Path) -> std::path::PathBuf {
    index_dir.join(format!("staging-{}", std::process::id()))
}
