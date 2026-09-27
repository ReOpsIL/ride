use std::path::{Path, PathBuf};

use ride_engine::{EngineConfig, engine_start, write_index};

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn config(index_dir: &Path) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: Some(fixtures().join("cargo_home").display().to_string()),
        sysroot: Some(fixtures().join("sysroot").display().to_string()),
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    }
}

fn copy_dir(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap().flatten() {
        let target = to.join(entry.file_name());
        if entry.path().is_dir() {
            copy_dir(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), &target).unwrap();
        }
    }
}

const TEXT: &str = "use sample::Foo;\nfn main() { let f = Foo::new(); }\n";

fn foo_sources(workspace: &Path, indexed: &Path, index_dir: &Path) -> Vec<String> {
    write_index(indexed, index_dir, &config(index_dir)).unwrap();
    let engine = engine_start(config(index_dir));
    engine
        .open_workspace(workspace.display().to_string())
        .unwrap();
    let main = workspace.join("src/bin_probe.rs").display().to_string();
    let open = engine
        .open_session("buf".into(), Some(main), TEXT.into(), None)
        .unwrap();
    let at = TEXT.find("Foo;").unwrap() as u32 + 1;
    engine
        .find_definitions(open.session_id, at)
        .hits
        .into_iter()
        .filter_map(|h| h.source_path)
        .collect()
}

fn under(sources: &[String], copy: &str) -> bool {
    sources.iter().any(|p| p.contains(&format!("/{copy}/")))
}

#[test]
fn index_hits_from_another_copy_of_the_workspace_are_dropped() {
    let dir = tempfile::tempdir().unwrap();
    let first = dir.path().join("first");
    let second = dir.path().join("second");
    copy_dir(&fixtures().join("sample_crate"), &first);
    copy_dir(&fixtures().join("sample_crate"), &second);
    let sources = foo_sources(&second, &first, &dir.path().join("index"));
    assert!(!under(&sources, "first"), "{sources:?}");
}

#[test]
fn index_hits_from_the_open_workspace_are_kept() {
    let dir = tempfile::tempdir().unwrap();
    let first = dir.path().join("first");
    copy_dir(&fixtures().join("sample_crate"), &first);
    let sources = foo_sources(&first, &first, &dir.path().join("index"));
    assert!(under(&sources, "first"), "{sources:?}");
}
