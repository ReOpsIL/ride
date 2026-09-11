use std::fs;
use std::path::Path;

use ride_engine::{EngineConfig, ProjectKind, ProjectModel, TargetKind, engine_start};

const DB: &str = r#"[
  {"directory": "DIR", "file": "src/a.c", "command": "cc -I include -c src/a.c -o a.o"},
  {"directory": "DIR", "file": "src/b.c", "arguments": ["cc", "-c", "src/b.c"]},
  {"directory": "DIR", "file": "src/a.c", "command": "cc -c src/a.c"}
]"#;

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

fn write_db(root: &Path, at: &str) {
    let path = root.join(at);
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, DB.replace("DIR", &root.display().to_string())).unwrap();
}

#[test]
fn every_source_becomes_a_custom_target() {
    let root = tempfile::tempdir().unwrap();
    write_db(root.path(), "compile_commands.json");
    let model = model(root.path());
    assert_eq!(model.kind, ProjectKind::CompileDb);
    let names: Vec<&str> = model.targets.iter().map(|t| t.name.as_str()).collect();
    assert_eq!(names, ["src/a.c", "src/b.c"]);
    assert!(model.targets.iter().all(|t| t.kind == TargetKind::Custom));
    assert!(model.targets.iter().all(|t| t.run.is_none()));
    assert!(model.notice.is_none());
}

#[test]
fn command_is_split_into_argv_and_directory_is_the_working_dir() {
    let root = tempfile::tempdir().unwrap();
    write_db(root.path(), "compile_commands.json");
    let model = model(root.path());
    let first = &model.targets[0];
    assert_eq!(
        first.build,
        ["cc", "-I", "include", "-c", "src/a.c", "-o", "a.o"]
    );
    assert_eq!(first.working_dir, root.path().display().to_string());
    assert_eq!(
        first.sources,
        [root.path().join("src/a.c").display().to_string()]
    );
    assert_eq!(model.targets[1].build, ["cc", "-c", "src/b.c"]);
}

#[test]
fn a_database_under_build_is_found_and_is_the_manifest() {
    let root = tempfile::tempdir().unwrap();
    write_db(root.path(), "build/compile_commands.json");
    let model = model(root.path());
    assert_eq!(model.kind, ProjectKind::CompileDb);
    assert_eq!(model.targets.len(), 2);
    assert_eq!(
        model.manifest,
        root.path()
            .join("build/compile_commands.json")
            .display()
            .to_string()
    );
}

#[test]
fn a_makefile_wins_over_a_compilation_database() {
    let root = tempfile::tempdir().unwrap();
    write_db(root.path(), "compile_commands.json");
    fs::write(root.path().join("Makefile"), "all:\n\t@true\n").unwrap();
    assert_eq!(model(root.path()).kind, ProjectKind::Make);
}

#[test]
fn a_broken_database_yields_a_notice_and_no_targets() {
    let root = tempfile::tempdir().unwrap();
    fs::write(root.path().join("compile_commands.json"), "{ not json").unwrap();
    let model = model(root.path());
    assert_eq!(model.kind, ProjectKind::CompileDb);
    assert!(model.targets.is_empty());
    assert!(model.notice.is_some());
}
