use std::path::{Path, PathBuf};
use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, Lang, SessionOpen, engine_start, extractor_for};

fn config(dir: &Path) -> EngineConfig {
    EngineConfig {
        index_dir: dir.join("index").display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
    }
}

fn engine_for(sample: &str) -> (tempfile::TempDir, Arc<Engine>, PathBuf) {
    let dir = tempfile::tempdir().unwrap();
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(sample);
    let engine = engine_start(config(dir.path()));
    engine.open_workspace(root.display().to_string()).unwrap();
    (dir, engine, root)
}

fn open(engine: &Engine, path: &Path) -> (SessionOpen, String) {
    let text = std::fs::read_to_string(path).unwrap();
    let open = engine
        .open_session(
            "hierarchy".into(),
            Some(path.display().to_string()),
            text.clone(),
            None,
        )
        .unwrap();
    (open, text)
}

fn at(text: &str, needle: &str, symbol: &str) -> u32 {
    let start = text.find(needle).unwrap() + needle.find(symbol).unwrap();
    start as u32 + 1
}

#[test]
fn callers_of_record_are_the_two_calls() {
    let (_dir, engine, root) = engine_for("samples/rust-demo");
    let main = root.join("src/main.rs");
    let (open, text) = open(&engine, &main);
    let records = extractor_for(Lang::Rust).extract(Lang::Rust, &text);
    engine
        .refs_update("src/main.rs".to_string(), records)
        .unwrap();

    let byte = at(&text, "counter.record(\"ride\")", "record");
    let resp = engine.callers(open.session_id, byte);
    assert_eq!(resp.name, "record");
    assert_eq!(resp.hits.len(), 2, "{:?}", resp.hits);
    assert!(resp.hits.iter().all(|h| h.ref_kind == "call"));

    let all = engine.find_usages(open.session_id, byte);
    assert!(
        all.hits.len() >= resp.hits.len(),
        "callers must be a subset of usages: {:?}",
        all.hits
    );
}

#[test]
fn callees_of_main_list_buffer_calls() {
    let (_dir, engine, root) = engine_for("samples/rust-demo");
    let main = root.join("src/main.rs");
    let (open, text) = open(&engine, &main);

    let byte = at(&text, "fn main()", "main");
    let names: Vec<String> = engine
        .callees(open.session_id, byte)
        .into_iter()
        .map(|c| c.name)
        .collect();
    assert!(names.contains(&"record".to_string()), "{names:?}");
    assert!(names.contains(&"count".to_string()), "{names:?}");
    assert_eq!(
        names.iter().filter(|n| *n == "record").count(),
        1,
        "callees are deduplicated: {names:?}"
    );
}

#[test]
fn rust_trait_impls_link_counter_and_recorder() {
    let (_dir, engine, root) = engine_for("samples/rust-demo");
    let util = root.join("src/util.rs");
    let (open, text) = open(&engine, &util);

    let counter = at(&text, "impl Recorder for Counter", "Counter");
    let up = engine.type_hierarchy(open.session_id, counter);
    assert_eq!(up.name, "Counter");
    let supers: Vec<String> = up.supertypes.iter().map(|n| n.name.clone()).collect();
    assert_eq!(supers, vec!["Recorder".to_string()]);
    assert!(up.subtypes.is_empty(), "{:?}", up.subtypes);

    let recorder = at(&text, "pub trait Recorder", "Recorder");
    let down = engine.type_hierarchy(open.session_id, recorder);
    assert_eq!(down.name, "Recorder");
    let subs: Vec<String> = down.subtypes.iter().map(|n| n.name.clone()).collect();
    assert_eq!(subs, vec!["Counter".to_string()]);
    assert!(down.supertypes.is_empty(), "{:?}", down.supertypes);
}

#[test]
fn cpp_bases_and_derived_classes() {
    let (_dir, engine, root) = engine_for("samples/cpp-demo");
    let header = root.join("include/shapes.hpp");
    let (open, text) = open(&engine, &header);

    let circle = at(&text, "class Circle : public Shape", "Circle");
    let up = engine.type_hierarchy(open.session_id, circle);
    assert_eq!(up.name, "Circle");
    let supers: Vec<String> = up.supertypes.iter().map(|n| n.name.clone()).collect();
    assert_eq!(supers, vec!["Shape".to_string()]);

    let shape = at(&text, "class Shape {", "Shape");
    let down = engine.type_hierarchy(open.session_id, shape);
    assert_eq!(down.name, "Shape");
    let mut subs: Vec<String> = down.subtypes.iter().map(|n| n.name.clone()).collect();
    subs.sort();
    assert_eq!(subs, vec!["Circle".to_string(), "Rect".to_string()]);
    assert!(
        down.subtypes.iter().all(|n| n.path.ends_with("shapes.hpp")),
        "{:?}",
        down.subtypes
    );
}
