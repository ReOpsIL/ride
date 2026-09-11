use std::fs;
use std::path::Path;

use ride_engine::{EngineConfig, ProjectKind, ProjectModel, TargetKind, engine_start};

fn copy_tree(from: &Path, to: &Path, skip: &[&str]) {
    fs::create_dir_all(to).unwrap();
    for entry in fs::read_dir(from).unwrap() {
        let entry = entry.unwrap();
        let name = entry.file_name();
        if skip.iter().any(|s| *s == name.to_string_lossy()) {
            continue;
        }
        let target = to.join(&name);
        if entry.file_type().unwrap().is_dir() {
            copy_tree(&entry.path(), &target, skip);
        } else {
            fs::copy(entry.path(), &target).unwrap();
        }
    }
}

fn make_only_demo() -> tempfile::TempDir {
    let root = tempfile::tempdir().unwrap();
    let source = Path::new(env!("CARGO_MANIFEST_DIR")).join("samples/cpp-demo");
    copy_tree(&source, root.path(), &["CMakeLists.txt", "build"]);
    root
}

fn model(root: &Path) -> ProjectModel {
    let index = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: index.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    engine.project_model(root.display().to_string()).unwrap()
}

#[test]
fn makefile_rules_become_custom_targets() {
    let root = make_only_demo();
    let model = model(root.path());
    assert_eq!(model.kind, ProjectKind::Make);
    assert_eq!(model.profiles, vec!["default".to_string()]);
    assert!(model.manifest.ends_with("Makefile"));
    let names: Vec<&str> = model.targets.iter().map(|t| t.name.as_str()).collect();
    for wanted in ["all", "run", "clean", "compile_commands", "build/demo"] {
        assert!(names.contains(&wanted), "{wanted} missing from {names:?}");
    }
    assert!(model.targets.iter().all(|t| t.kind == TargetKind::Custom));
    let all = model.targets.iter().find(|t| t.name == "all").unwrap();
    assert_eq!(all.build, vec!["make".to_string(), "all".to_string()]);
    assert_eq!(
        all.run,
        Some(vec!["make".to_string(), "run".to_string()]),
        "a run rule exists"
    );
    assert_eq!(all.working_dir, root.path().display().to_string());
}

#[test]
fn pattern_and_special_rules_are_skipped() {
    let root = make_only_demo();
    let names: Vec<String> = model(root.path())
        .targets
        .into_iter()
        .map(|t| t.name)
        .collect();
    assert!(!names.iter().any(|n| n.contains('%')));
    assert!(!names.iter().any(|n| n.starts_with('.')));
    assert!(!names.iter().any(|n| n == "build/compile_commands.json"));
}

#[test]
fn dry_run_lists_the_sources_of_the_binary() {
    let root = make_only_demo();
    let model = model(root.path());
    let demo = model
        .targets
        .iter()
        .find(|t| t.name == "build/demo")
        .unwrap();
    assert!(
        demo.sources.iter().any(|s| s == "src/main.cpp"),
        "{:?}",
        demo.sources
    );
    assert!(demo.sources.iter().any(|s| s == "src/shapes.cpp"));
    assert!(!root.path().join("build/demo").exists());
}

#[test]
fn no_makefile_is_not_a_make_project() {
    let root = tempfile::tempdir().unwrap();
    fs::write(root.path().join("notes.txt"), "x").unwrap();
    assert_eq!(model(root.path()).kind, ProjectKind::None);
}

#[test]
fn a_cargo_manifest_beside_a_makefile_is_not_a_make_project() {
    let root = tempfile::tempdir().unwrap();
    fs::write(root.path().join("Makefile"), "all:\n\ttrue\n").unwrap();
    fs::write(root.path().join("Cargo.toml"), "[package]\nname = \"x\"\n").unwrap();
    assert_eq!(model(root.path()).kind, ProjectKind::Cargo);
}

#[test]
fn the_make_detector_reads_the_real_cpp_demo_beside_its_cmake_lists() {
    use ride_engine::project::{Detect, make::Make};
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("samples/cpp-demo");
    let config = EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    };
    let model = Make::detect(&root, &config).unwrap().unwrap();
    assert_eq!(model.kind, ProjectKind::Make);
    let names: Vec<&str> = model.targets.iter().map(|t| t.name.as_str()).collect();
    for expected in ["all", "run", "clean", "compile_commands", "build/demo"] {
        assert!(
            names.contains(&expected),
            "{expected} missing from {names:?}"
        );
    }
}
