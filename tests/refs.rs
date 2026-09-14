use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Instant;

use ride_engine::{
    Engine, EngineConfig, ItemKind, Lang, RefKind, RefRecord, engine_start, extractor_for,
};

fn config(dir: &Path) -> EngineConfig {
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

fn line_of(text: &str, byte: usize) -> u32 {
    text[..byte].bytes().filter(|&c| c == b'\n').count() as u32 + 1
}

fn call_record(text: &str, name: &str, byte: usize) -> RefRecord {
    RefRecord {
        name: name.to_string(),
        kind: RefKind::Call,
        path: "src/main.rs".to_string(),
        line: line_of(text, byte),
        byte_start: byte as u32,
        byte_end: (byte + name.len()) as u32,
        enclosing_item: "main".to_string(),
        enclosing_kind: ItemKind::Fn,
    }
}

fn demo_records(text: &str) -> Vec<RefRecord> {
    let r1 = text.find("record(").unwrap();
    let r2 = text[r1 + 1..].find("record(").unwrap() + r1 + 1;
    let c1 = text.find("count(").unwrap();
    vec![
        call_record(text, "record", r1),
        call_record(text, "record", r2),
        call_record(text, "count", c1),
    ]
}

#[test]
fn find_usages_groups_and_replaces() {
    let (_dir, engine, root) = demo_engine();
    let main = root.join("src/main.rs");
    let text = std::fs::read_to_string(&main).unwrap();
    let open = engine
        .open_session(
            "demo".into(),
            Some(main.display().to_string()),
            text.clone(),
            None,
        )
        .unwrap();

    let records = demo_records(&text);
    engine
        .refs_update("src/main.rs".to_string(), records.clone())
        .unwrap();

    let started = Instant::now();
    engine
        .refs_update("src/main.rs".to_string(), records.clone())
        .unwrap();
    let elapsed = started.elapsed();
    assert!(
        elapsed.as_millis() < 250,
        "incremental update should be far below a rebuild: {elapsed:?}"
    );

    let at = text.find("record(").unwrap() as u32 + 1;
    let resp = engine.find_usages(open.session_id, at);
    assert_eq!(resp.name, "record");
    assert_eq!(resp.hits.len(), 2, "{:?}", resp.hits);
    assert!(resp.hits.iter().all(|h| h.path == "src/main.rs"));

    engine
        .refs_update("src/main.rs".to_string(), records)
        .unwrap();
    let again = engine.find_usages(open.session_id, at);
    assert_eq!(again.hits.len(), 2, "replace duplicated: {:?}", again.hits);
}

#[test]
fn cpp_extractor_yields_call_for_header_method() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/cpp-demo");
    let main = root.join("src/main.cpp");
    let text = std::fs::read_to_string(&main).unwrap();

    let records = extractor_for(Lang::Cpp).extract(Lang::Cpp, &text);

    let describe = records
        .iter()
        .find(|r| r.kind == RefKind::Call && r.name == "describe")
        .expect("call to Shape::describe should yield a Call record");
    assert_eq!(describe.enclosing_item, "main");
    assert_eq!(describe.enclosing_kind, ItemKind::Fn);
    assert_eq!(
        &text[describe.byte_start as usize..describe.byte_end as usize],
        "describe"
    );

    assert!(
        records
            .iter()
            .any(|r| r.kind == RefKind::Include && r.name == "shapes.hpp"),
        "include of shapes.hpp should yield an Include record"
    );
}
