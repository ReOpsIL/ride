use ride_engine::{EngineConfig, ProjectKind, ProjectModel, TargetKind, engine_start};

fn model(root: &str) -> (tempfile::TempDir, ProjectModel) {
    let index = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: index.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    let model = engine.project_model(root.to_string()).unwrap();
    (index, model)
}

#[test]
fn rust_demo_has_one_bin_and_one_test() {
    let (_index, model) = model("samples/rust-demo");
    assert_eq!(model.kind, ProjectKind::Cargo);
    assert!(model.manifest.ends_with("samples/rust-demo/Cargo.toml"));
    assert_eq!(model.profiles, vec!["debug", "release"]);
    let bins: Vec<_> = model
        .targets
        .iter()
        .filter(|t| t.kind == TargetKind::Bin)
        .collect();
    assert_eq!(bins.len(), 1);
    assert_eq!(bins[0].name, "ride-demo");
    assert_eq!(
        bins[0].build,
        vec!["cargo", "build", "-p", "ride-demo", "--bin", "ride-demo"]
    );
    assert_eq!(
        bins[0].run.clone().unwrap(),
        vec!["cargo", "run", "-p", "ride-demo", "--bin", "ride-demo"]
    );
    assert!(bins[0].sources[0].ends_with("src/main.rs"));
    assert_eq!(bins[0].working_dir, model.root);
    let tests: Vec<_> = model
        .targets
        .iter()
        .filter(|t| t.kind == TargetKind::Test)
        .collect();
    assert_eq!(tests.len(), 1);
    assert_eq!(tests[0].build, vec!["cargo", "test", "-p", "ride-demo"]);
    assert!(tests[0].run.is_none());
}

#[test]
fn sample_crate_yields_a_lib_target() {
    let (_index, model) = model("tests/fixtures/sample_crate");
    assert_eq!(model.kind, ProjectKind::Cargo);
    let libs: Vec<_> = model
        .targets
        .iter()
        .filter(|t| t.kind == TargetKind::Lib)
        .collect();
    assert_eq!(libs.len(), 1);
    assert_eq!(libs[0].name, "sample");
    assert_eq!(
        libs[0].build,
        vec!["cargo", "build", "-p", "sample", "--lib"]
    );
    assert!(libs[0].run.is_none());
    assert!(libs[0].sources[0].ends_with("src/lib.rs"));
    assert!(
        model
            .targets
            .iter()
            .any(|t| t.kind == TargetKind::Test && t.name == "sample")
    );
}

#[test]
fn an_unreadable_manifest_still_detects_cargo_without_targets() {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("Cargo.toml"), "[package]\nname = \"x\"\n").unwrap();
    let (_index, model) = model(&root.path().display().to_string());
    assert_eq!(model.kind, ProjectKind::Cargo);
    assert!(model.targets.is_empty());
    assert_eq!(model.profiles, vec!["debug", "release"]);
}
