use std::collections::BTreeMap;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::error::EngineError;
use crate::ffi::{IndexState, IndexStatus};

use super::schema::SCHEMA_VERSION;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub schema_version: u32,
    pub engine_semver: String,
    pub generation: u32,
    pub live_dir: String,
    #[serde(default)]
    pub fingerprint: String,
    #[serde(default)]
    pub docs: u32,
    #[serde(default)]
    pub crate_hashes: BTreeMap<String, String>,
}

impl Manifest {
    pub fn next(
        generation: u32,
        fingerprint: String,
        docs: u32,
        crate_hashes: BTreeMap<String, String>,
    ) -> Self {
        Self {
            schema_version: SCHEMA_VERSION,
            engine_semver: env!("CARGO_PKG_VERSION").to_string(),
            generation,
            live_dir: format!("gen-{generation}"),
            fingerprint,
            docs,
            crate_hashes,
        }
    }
}

#[derive(Serialize, Deserialize)]
struct StatusLine {
    state: String,
    docs: u32,
    crates_done: u32,
    crates_total: u32,
    rust_src_available: bool,
    #[serde(default)]
    warnings: u32,
    message: Option<String>,
}

pub fn read_manifest(index_dir: &Path) -> Option<Manifest> {
    let text = fs::read_to_string(index_dir.join("manifest.json")).ok()?;
    serde_json::from_str(&text).ok()
}

pub fn write_manifest_atomic(index_dir: &Path, manifest: &Manifest) -> Result<(), EngineError> {
    let tmp = index_dir.join("manifest.json.tmp");
    let dest = index_dir.join("manifest.json");
    let body = serde_json::to_vec_pretty(manifest).map_err(|e| EngineError::Index {
        message: e.to_string(),
    })?;
    fs::write(&tmp, &body).map_err(|e| EngineError::io(&tmp, e))?;
    if let Ok(f) = fs::File::open(&tmp) {
        let _ = f.sync_all();
    }
    fs::rename(&tmp, &dest).map_err(|e| EngineError::io(&dest, e))
}

pub fn append_status(index_dir: &Path, status: &IndexStatus) -> Result<(), EngineError> {
    let path = index_dir.join("status.jsonl");
    let line = StatusLine {
        state: state_label(status.state).to_string(),
        docs: status.docs,
        crates_done: status.crates_done,
        crates_total: status.crates_total,
        rust_src_available: status.rust_src_available,
        warnings: status.warnings,
        message: status.message.clone(),
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
        .map_err(|e| EngineError::io(&path, e))?;
    Ok(())
}

pub fn last_status(index_dir: &Path) -> Option<IndexStatus> {
    let text = fs::read_to_string(index_dir.join("status.jsonl")).ok()?;
    let line = text.lines().rev().find(|l| !l.trim().is_empty())?;
    let parsed: StatusLine = serde_json::from_str(line).ok()?;
    Some(IndexStatus {
        state: parse_state(&parsed.state),
        docs: parsed.docs,
        crates_done: parsed.crates_done,
        crates_total: parsed.crates_total,
        rust_src_available: parsed.rust_src_available,
        warnings: parsed.warnings,
        message: parsed.message,
    })
}

fn state_label(state: IndexState) -> &'static str {
    match state {
        IndexState::Idle => "idle",
        IndexState::Indexing => "indexing",
        IndexState::Ready => "ready",
        IndexState::Rebuilding => "rebuilding",
        IndexState::Error => "error",
    }
}

fn parse_state(s: &str) -> IndexState {
    match s {
        "indexing" => IndexState::Indexing,
        "ready" => IndexState::Ready,
        "rebuilding" => IndexState::Rebuilding,
        "error" => IndexState::Error,
        _ => IndexState::Idle,
    }
}
