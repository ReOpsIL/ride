use std::path::{Path, PathBuf};
use std::process::Command;

use ride_engine::{EngineConfig, ProjectKind, ProjectModel, Target, TargetKind, engine_start};

const SCENARIOS: [&str; 9] = [
    "stepping",
    "stack",
    "recursion",
    "loops",
    "data",
    "dispatch",
    "threads",
    "faults",
    "heartbeat",
];

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

fn has_cmake() -> bool {
    Command::new("cmake")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn lab() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("samples/debugger")
}

fn project<'a>(projects: &'a [ProjectModel], folder: &str) -> &'a ProjectModel {
    let root = lab().join(folder).display().to_string();
    projects.iter().find(|p| p.root == root).expect(folder)
}

fn lab_binary(model: &ProjectModel) -> &Target {
    model
        .targets
        .iter()
        .find(|t| t.name == "debugger-lab" && t.kind == TargetKind::Bin)
        .expect("debugger-lab target")
}

fn scenario_files(extension: &str) -> Vec<String> {
    SCENARIOS
        .iter()
        .map(|scenario| format!("src/{scenario}.{extension}"))
        .collect()
}

fn assert_scenarios_exist(model: &ProjectModel, extension: &str) {
    for file in scenario_files(extension) {
        assert!(Path::new(&model.root).join(&file).is_file(), "{file}");
    }
}

#[test]
fn the_lab_folder_holds_one_project_per_language() {
    let (_index, engine) = engine();
    let projects = engine
        .workspace_projects(lab().display().to_string())
        .unwrap();
    let mut roots: Vec<String> = projects.iter().map(|p| p.root.clone()).collect();
    roots.sort();
    let expected: Vec<String> = ["c", "cpp", "rust"]
        .iter()
        .map(|folder| lab().join(folder).display().to_string())
        .collect();
    assert_eq!(roots, expected);
    let rust = project(&projects, "rust");
    assert_eq!(rust.kind, ProjectKind::Cargo);
    lab_binary(rust);
    assert_scenarios_exist(rust, "rs");
    if !has_cmake() {
        return;
    }
    for (folder, extension) in [("cpp", "cpp"), ("c", "c")] {
        let model = project(&projects, folder);
        assert_eq!(model.kind, ProjectKind::CMake);
        assert_eq!(model.notice, None, "{folder}");
        let sources = &lab_binary(model).sources;
        for file in scenario_files(extension) {
            assert!(sources.contains(&file), "{file} not in {sources:?}");
        }
        assert_scenarios_exist(model, extension);
    }
}
