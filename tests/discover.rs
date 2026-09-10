use std::path::PathBuf;

use ride_engine::{EngineConfig, IndexState, Scope, discover, engine_start, workspace_info};

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn config() -> EngineConfig {
    EngineConfig {
        index_dir: ".".into(),
        cargo_home: Some(fixtures().join("cargo_home").display().to_string()),
        sysroot: Some(fixtures().join("sysroot").display().to_string()),
        offline_metadata: true,
    }
}

#[test]
fn fake_cargo_home_and_sysroot() {
    let d = discover(&config(), None).unwrap();
    assert!(d.rust_src_available);
    assert!(
        d.unpacked
            .iter()
            .any(|c| c.name == "demo" && c.version == "1.2.3" && c.scope == Scope::Cache)
    );
    assert!(d.unpacked.iter().any(|c| c.name == "gitdemo"));
    assert!(
        d.unpacked
            .iter()
            .any(|c| c.name == "std" && c.scope == Scope::Sysroot)
    );
    assert!(
        d.unpacked
            .iter()
            .any(|c| c.name == "core" && c.scope == Scope::Sysroot)
    );
    assert!(
        d.unpacked
            .iter()
            .any(|c| c.name == "alloc" && c.scope == Scope::Sysroot)
    );
    assert!(d.tarballs.iter().any(|t| t.file_name == "demo-1.2.3.crate"));
}

#[test]
fn workspace_metadata_offline() {
    let root = fixtures().join("workspace");
    let info = workspace_info(&root, &config()).unwrap();
    assert!(info.is_cargo);
    assert_eq!(info.package_name.as_deref(), Some("ride_fixture_app"));
    assert!(info.members.iter().any(|m| m == "ride_fixture_app"));
    assert!(info.rust_src_available);
}

#[test]
fn plain_folder_is_not_cargo() {
    let dir = tempfile::tempdir().unwrap();
    let info = workspace_info(dir.path(), &config()).unwrap();
    assert!(!info.is_cargo);
    assert!(info.package_name.is_none());
}

#[test]
fn engine_starts_idle() {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: dir.path().display().to_string(),
        cargo_home: config().cargo_home,
        sysroot: config().sysroot,
        offline_metadata: true,
    });
    let s = engine.status();
    assert_eq!(s.state, IndexState::Idle);
    let open = engine
        .open_workspace(fixtures().join("workspace").display().to_string())
        .unwrap();
    assert_eq!(open.package_name.as_deref(), Some("ride_fixture_app"));
    let session = engine
        .open_session("buf".into(), None, "fn main() {}".into(), None)
        .unwrap();
    assert!(session.session_id >= 1);
    engine.close_session(session.session_id);
    engine.close_workspace();
}

#[test]
fn tool_status_lists_every_tool_with_a_hint() {
    let tools = ride_engine::tool_status();
    let names: Vec<&str> = tools.iter().map(|t| t.name.as_str()).collect();
    assert!(
        names.contains(&"rustfmt") && names.contains(&"clang-format") && names.contains(&"taplo")
    );
    assert!(
        tools
            .iter()
            .all(|t| !t.purpose.is_empty() && !t.hint.is_empty())
    );
    let git = tools.iter().find(|t| t.name == "git").unwrap();
    assert!(git.path.is_some());
}
