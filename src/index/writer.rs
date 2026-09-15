use std::fs;
use std::path::Path;

use crate::discover::discover;
use crate::error::EngineError;
use crate::ffi::{EngineConfig, IndexState, IndexStatus};

use super::build::build;
use super::crates::collect_crates;
use super::fingerprint::{HashedCrate, fingerprint, hash_crates};
use super::gc::clean_stagings;
use super::incremental::{self, key_of};
use super::promote::promote;
use super::schema::SCHEMA_VERSION;
use super::status::{Manifest, append_status, read_manifest};

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
    let crate_hashes = hashed.iter().map(|h| (key_of(h), h.hash.clone())).collect();
    match write(index_dir, prev.as_ref(), &hashed, &mut status, force) {
        Ok(docs) => {
            let generation = prev.as_ref().map(|m| m.generation + 1).unwrap_or(1);
            let manifest = Manifest::next(generation, fp, docs, crate_hashes);
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

fn write(
    index_dir: &Path,
    prev: Option<&Manifest>,
    hashed: &[HashedCrate],
    status: &mut IndexStatus,
    force: bool,
) -> Result<u32, EngineError> {
    if !force
        && let Some(prev) = prev.filter(|m| m.schema_version == SCHEMA_VERSION)
        && let Some(delta) = incremental::delta(prev, hashed)
        && index_dir.join(&prev.live_dir).is_dir()
    {
        status.crates_total = delta.changed.len() as u32;
        append_status(index_dir, status)?;
        return incremental::apply(
            index_dir,
            &index_dir.join(&prev.live_dir),
            &staging_dir(index_dir),
            &delta,
            status,
        );
    }
    build(index_dir, &staging_dir(index_dir), hashed, status)
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
