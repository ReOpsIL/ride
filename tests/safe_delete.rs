use std::path::{Path, PathBuf};
use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, engine_start};

fn config(dir: &Path) -> EngineConfig {
    EngineConfig {
        index_dir: dir.join("index").display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    }
}

fn engine_for(root: &Path) -> (tempfile::TempDir, Arc<Engine>) {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(config(dir.path()));
    engine.open_workspace(root.display().to_string()).unwrap();
    (dir, engine)
}

fn open(engine: &Engine, path: &Path) -> (u64, String) {
    let text = std::fs::read_to_string(path).unwrap();
    let opened = engine
        .open_session(
            "s".into(),
            Some(path.display().to_string()),
            text.clone(),
            None,
        )
        .unwrap();
    (opened.session_id, text)
}

fn at_name(text: &str, needle: &str, name: &str) -> u32 {
    let start = text.find(needle).unwrap() + needle.find(name).unwrap();
    start as u32 + 1
}

#[test]
fn unused_fn_has_one_file_and_empty_review() {
    let crate_dir = tempfile::tempdir().unwrap();
    let src = crate_dir.path().join("src");
    std::fs::create_dir_all(&src).unwrap();
    let lib = src.join("lib.rs");
    let body = "/// leftover docs\nfn unused() {}\n\nfn kept() {}\n";
    std::fs::write(&lib, body).unwrap();

    let (_idx, engine) = engine_for(crate_dir.path());
    let (id, text) = open(&engine, &lib);
    engine.note_saved(id).unwrap();

    let plan = engine.safe_delete_plan(id, at_name(&text, "fn unused()", "unused"));
    assert_eq!(plan.name, "unused");
    assert!(plan.new_name.is_empty());
    assert_eq!(plan.files.len(), 1, "{:?}", plan.files);
    assert!(plan.review.is_empty(), "{:?}", plan.review);
    let edit = &plan.files[0].edits[0];
    assert!(edit.text.is_empty());
    let deleted = &text[edit.start_byte as usize..edit.end_byte as usize];
    assert!(deleted.contains("leftover docs"), "{deleted:?}");
    assert!(deleted.contains("fn unused"), "{deleted:?}");
    assert!(!deleted.contains("fn kept"), "{deleted:?}");
}

#[test]
fn record_review_lists_both_call_sites() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/rust-demo");
    let (_idx, engine) = engine_for(&root);
    let (util_id, util_text) = open(&engine, &root.join("src/util.rs"));
    let (main_id, main_text) = open(&engine, &root.join("src/main.rs"));
    engine.note_saved(util_id).unwrap();
    engine.note_saved(main_id).unwrap();

    let plan = engine.safe_delete_plan(
        util_id,
        at_name(&util_text, "fn record(&mut self, name: &str);", "record"),
    );
    assert_eq!(plan.name, "record");
    assert!(plan.new_name.is_empty());
    assert_eq!(plan.files.len(), 1, "{:?}", plan.files);
    assert_eq!(plan.files[0].path, "src/util.rs");
    assert!(plan.files[0].edits[0].text.is_empty());

    let main = plan
        .review
        .iter()
        .find(|file| file.path == "src/main.rs")
        .unwrap_or_else(|| panic!("review {:?}", plan.review));
    assert_eq!(main.edits.len(), 2, "{:?}", main.edits);
    for edit in &main.edits {
        assert!(edit.text.is_empty());
        assert_eq!(
            &main_text[edit.start_byte as usize..edit.end_byte as usize],
            "record"
        );
    }
}
