#![allow(dead_code)]

use std::path::{Path, PathBuf};
use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, engine_start, write_index};

pub fn manifest() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

pub fn fixtures() -> PathBuf {
    manifest().join("tests/fixtures")
}

pub fn config(index_dir: &Path) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: Some(fixtures().join("cargo_home").display().to_string()),
        sysroot: Some(fixtures().join("sysroot").display().to_string()),
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    }
}

pub fn engine() -> (tempfile::TempDir, Arc<Engine>) {
    let dir = tempfile::tempdir().unwrap();
    let crate_root = fixtures().join("sample_crate");
    write_index(&crate_root, dir.path(), &config(dir.path())).unwrap();
    let engine = engine_start(config(dir.path()));
    engine
        .open_workspace(crate_root.display().to_string())
        .unwrap();
    (dir, engine)
}
