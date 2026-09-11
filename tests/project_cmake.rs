use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use ride_engine::{EngineConfig, ProjectKind, Target, TargetKind, engine_start};

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

fn has_cmake() -> bool {
    Command::new("cmake")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn cpp_demo() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("samples/cpp-demo")
}

fn named<'a>(targets: &'a [Target], name: &str) -> &'a Target {
    targets.iter().find(|t| t.name == name).unwrap()
}

#[test]
fn cpp_demo_targets_come_from_the_file_api() {
    if !has_cmake() {
        return;
    }
    let (_index, engine) = engine();
    let model = engine
        .project_model(cpp_demo().display().to_string())
        .unwrap();
    assert_eq!(model.kind, ProjectKind::CMake);
    assert_eq!(model.notice, None);
    assert_eq!(model.profiles, ["Debug", "Release", "RelWithDebInfo"]);
    assert!(model.manifest.ends_with("CMakeLists.txt"));

    let demo = named(&model.targets, "demo");
    assert_eq!(demo.kind, TargetKind::Bin);
    assert!(demo.sources.contains(&"src/main.cpp".to_string()));
    assert_eq!(
        demo.build,
        ["cmake", "--build", "build/Debug", "--target", "demo"]
    );
    assert_eq!(
        demo.run.as_deref(),
        Some(["build/Debug/demo".to_string()].as_slice())
    );
    assert_eq!(demo.working_dir, cpp_demo().display().to_string());

    let shapes = named(&model.targets, "shapes");
    assert_eq!(shapes.kind, TargetKind::Lib);
    assert_eq!(shapes.run, None);

    assert!(
        cpp_demo()
            .join("build/Debug/compile_commands.json")
            .is_file()
    );
}

#[test]
fn a_broken_manifest_yields_a_notice_and_no_targets() {
    if !has_cmake() {
        return;
    }
    let root = tempfile::tempdir().unwrap();
    fs::write(
        root.path().join("CMakeLists.txt"),
        "cmake_minimum_required(VERSION 99.9)\nproject(broken)\n",
    )
    .unwrap();
    let (_index, engine) = engine();
    let model = engine
        .project_model(root.path().display().to_string())
        .unwrap();
    assert_eq!(model.kind, ProjectKind::CMake);
    assert!(model.targets.is_empty());
    assert!(model.notice.unwrap().starts_with("cmake configure failed"));
}
