use std::fs;

use ride_engine::{EngineConfig, ProjectKind, engine_start};

fn engine() -> (tempfile::TempDir, std::sync::Arc<ride_engine::Engine>) {
    let index = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: index.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    (index, engine)
}

#[test]
fn empty_dir_is_none() {
    let root = tempfile::tempdir().unwrap();
    let (_index, engine) = engine();
    let model = engine
        .project_model(root.path().display().to_string())
        .unwrap();
    assert_eq!(model.kind, ProjectKind::None);
    assert!(model.targets.is_empty());
    assert!(model.profiles.is_empty());
    assert!(model.manifest.is_empty());
}

#[test]
fn cargo_wins_over_cmake_when_both_manifests_exist() {
    let root = tempfile::tempdir().unwrap();
    fs::write(root.path().join("Cargo.toml"), "[package]\nname = \"x\"\n").unwrap();
    fs::write(root.path().join("CMakeLists.txt"), "project(x)\n").unwrap();
    let (_index, engine) = engine();
    let model = engine
        .project_model(root.path().display().to_string())
        .unwrap();
    assert_eq!(model.kind, ProjectKind::Cargo);
    assert!(model.targets.is_empty());
}

#[test]
fn reload_replaces_a_cached_none() {
    let root = tempfile::tempdir().unwrap();
    let (_index, engine) = engine();
    let path = root.path().display().to_string();
    let first = engine.project_model(path.clone()).unwrap();
    assert_eq!(first.kind, ProjectKind::None);
    fs::write(root.path().join("Cargo.toml"), "[package]\nname = \"x\"\n").unwrap();
    assert_eq!(
        engine.project_model(path.clone()).unwrap().kind,
        ProjectKind::None
    );
    assert_eq!(
        engine.reload_project(path).unwrap().kind,
        ProjectKind::Cargo
    );
}
