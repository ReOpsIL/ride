use std::path::PathBuf;
use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, engine_start};

fn config(dir: &std::path::Path) -> EngineConfig {
    EngineConfig {
        index_dir: dir.join("index").display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    }
}

fn demo_engine() -> (tempfile::TempDir, Arc<Engine>, PathBuf) {
    let dir = tempfile::tempdir().unwrap();
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/rust-demo");
    let engine = engine_start(config(dir.path()));
    engine.open_workspace(root.display().to_string()).unwrap();
    (dir, engine, root)
}

fn open(engine: &Engine, path: &std::path::Path) -> (u64, String) {
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

#[test]
fn rename_local_edits_every_counter_occurrence() {
    let (_dir, engine, root) = demo_engine();
    let (id, text) = open(&engine, &root.join("src/main.rs"));

    let at = text.find("counter").unwrap() as u32 + 1;
    let edits = engine.rename_local(id, at, "tally".into());

    let expected = text.matches("counter").count();
    assert_eq!(edits.len(), expected, "{edits:?}");
    for edit in &edits {
        assert_eq!(edit.text, "tally");
        assert_eq!(
            &text[edit.start_byte as usize..edit.end_byte as usize],
            "counter"
        );
    }

    let main_start = text.find("fn main").unwrap() as u32;
    let main_end = text.len() as u32;
    assert!(
        edits
            .iter()
            .all(|e| e.start_byte >= main_start && e.end_byte <= main_end)
    );
}

#[test]
fn rename_local_refuses_invalid_identifier() {
    let (_dir, engine, root) = demo_engine();
    let (id, text) = open(&engine, &root.join("src/main.rs"));

    let at = text.find("counter").unwrap() as u32 + 1;
    assert!(engine.rename_local(id, at, "1bad".into()).is_empty());
    assert!(engine.rename_local(id, at, "fn".into()).is_empty());
    assert!(
        engine
            .rename_plan(id, at, "has space".into())
            .files
            .is_empty()
    );
}

#[test]
fn rename_local_refuses_non_local() {
    let (_dir, engine, root) = demo_engine();
    let (id, text) = open(&engine, &root.join("src/main.rs"));

    let at = text.find("HashMap").unwrap() as u32 + 1;
    assert!(engine.rename_local(id, at, "Map".into()).is_empty());
}

#[test]
fn rename_plan_lists_unresolved_matches_for_review() {
    let (_dir, engine, root) = demo_engine();
    let (main_id, main_text) = open(&engine, &root.join("src/main.rs"));
    let (util_id, _) = open(&engine, &root.join("src/util.rs"));

    engine.note_saved(main_id).unwrap();
    engine.note_saved(util_id).unwrap();

    let at = main_text.find("record(").unwrap() as u32 + 1;
    let plan = engine.rename_plan(main_id, at, "log".into());

    assert_eq!(plan.name, "record");
    assert_eq!(plan.new_name, "log");
    let mut covered: Vec<&str> = plan
        .files
        .iter()
        .chain(plan.review.iter())
        .map(|f| f.path.as_str())
        .collect();
    covered.sort_unstable();
    covered.dedup();
    assert!(covered.contains(&"src/main.rs"), "{covered:?}");
    assert!(covered.contains(&"src/util.rs"), "{covered:?}");
    assert!(
        plan.files.is_empty() && !plan.review.is_empty(),
        "an unresolved workspace symbol must not auto-edit: files={:?} review={:?}",
        plan.files,
        plan.review
    );
    let review_paths: Vec<&str> = plan.review.iter().map(|f| f.path.as_str()).collect();
    assert!(review_paths.contains(&"src/main.rs"), "{review_paths:?}");
    assert!(review_paths.contains(&"src/util.rs"), "{review_paths:?}");
    for file in &plan.review {
        assert!(!file.edits.is_empty());
        assert!(file.edits.iter().all(|e| e.text == "log"));
    }
}
