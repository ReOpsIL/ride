use std::fs;

use ride_engine::{EngineConfig, ProjectKind, engine_start};

fn engine() -> (tempfile::TempDir, std::sync::Arc<ride_engine::Engine>) {
    let index = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: index.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
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

fn write(root: &std::path::Path, rel: &str, text: &str) {
    let path = root.join(rel);
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, text).unwrap();
}

#[test]
fn folder_of_crates_lists_each_crate_as_a_project() {
    let root = tempfile::tempdir().unwrap();
    write(root.path(), "CURRICULUM.md", "# lessons\n");
    write(
        root.path(),
        "lesson02/Cargo.toml",
        "[package]\nname = \"b\"\n",
    );
    write(
        root.path(),
        "lesson01/Cargo.toml",
        "[package]\nname = \"a\"\n",
    );
    write(root.path(), "extra/c/Makefile", "all:\n\techo hi\n");
    write(root.path(), "lesson01/target/debug/Makefile", "all:\n");
    write(
        root.path(),
        ".hidden/Cargo.toml",
        "[package]\nname = \"h\"\n",
    );
    let (_index, engine) = engine();
    let projects = engine
        .workspace_projects(root.path().display().to_string())
        .unwrap();
    let roots: Vec<String> = projects.iter().map(|p| p.root.clone()).collect();
    let expected: Vec<String> = ["extra/c", "lesson01", "lesson02"]
        .iter()
        .map(|rel| root.path().join(rel).display().to_string())
        .collect();
    assert_eq!(roots, expected);
    assert_eq!(projects[0].kind, ProjectKind::Make);
    assert_eq!(projects[1].kind, ProjectKind::Cargo);
}

#[test]
fn a_project_root_owns_its_subtree() {
    let root = tempfile::tempdir().unwrap();
    write(root.path(), "CMakeLists.txt", "project(x)\n");
    write(root.path(), "sub/CMakeLists.txt", "add_library(y y.c)\n");
    write(root.path(), "tools/Cargo.toml", "[package]\nname = \"t\"\n");
    let (_index, engine) = engine();
    let projects = engine
        .workspace_projects(root.path().display().to_string())
        .unwrap();
    assert_eq!(projects.len(), 1);
    assert_eq!(projects[0].root, root.path().display().to_string());
}

#[test]
fn folder_without_projects_yields_the_folder_itself() {
    let root = tempfile::tempdir().unwrap();
    write(root.path(), "notes/readme.md", "hi\n");
    let (_index, engine) = engine();
    let projects = engine
        .workspace_projects(root.path().display().to_string())
        .unwrap();
    assert_eq!(projects.len(), 1);
    assert_eq!(projects[0].kind, ProjectKind::None);
}

#[test]
fn check_of_a_nested_crate_reports_paths_inside_that_crate() {
    let root = tempfile::tempdir().unwrap();
    let manifest = "[package]\nname = \"lesson\"\nversion = \"0.1.0\"\nedition = \"2021\"\n";
    write(root.path(), "lesson/Cargo.toml", manifest);
    write(
        root.path(),
        "lesson/src/main.rs",
        "fn main() {\n    let x: u32 = \"no\";\n}\n",
    );
    let (_index, engine) = engine();
    engine
        .open_workspace(root.path().display().to_string())
        .unwrap();
    let lesson = root.path().join("lesson");
    let result = engine
        .run_check(lesson.display().to_string(), false)
        .unwrap();
    let error = result
        .diagnostics
        .iter()
        .find(|d| d.level == ride_engine::DiagnosticLevel::Error)
        .expect("type error reported");
    assert_eq!(
        std::path::Path::new(&error.path).canonicalize().unwrap(),
        lesson.join("src/main.rs").canonicalize().unwrap()
    );
}
