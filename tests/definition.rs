use std::path::PathBuf;
use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, ItemKind, engine_start, write_index};

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn config(index_dir: &std::path::Path) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: Some(fixtures().join("cargo_home").display().to_string()),
        sysroot: Some(fixtures().join("sysroot").display().to_string()),
        offline_metadata: true,
    }
}

fn engine() -> (tempfile::TempDir, Arc<Engine>) {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    (dir, engine)
}

const TEXT: &str = "use std::collections::HashMap;\nfn helper() {}\nfn main() {\n    let m: HashMap<u8, u8> = HashMap::default();\n    helper();\n    let x = std::collections::HashSet;\n}\n";

fn byte_of(needle: &str, nth: usize) -> u32 {
    TEXT.match_indices(needle).nth(nth).map(|(i, _)| i).unwrap() as u32 + 1
}

#[test]
fn catalog_symbol_resolves_to_source() {
    let (_dir, engine) = engine();
    let open = engine
        .open_session("buf".into(), None, TEXT.into(), None)
        .unwrap();
    let resp = engine.find_definitions(open.session_id, byte_of("HashMap<", 0));
    let symbol = resp.symbol.expect("symbol");
    assert_eq!(symbol.name, "HashMap");
    assert!(symbol.qualifier.is_none());
    let hit = &resp.hits[0];
    assert_eq!(hit.path, "std::collections::HashMap");
    assert_eq!(hit.item_kind, ItemKind::Struct);
    assert!(
        hit.source_path
            .as_deref()
            .unwrap()
            .ends_with("collections.rs")
    );
    assert!(hit.byte_end.unwrap() > hit.byte_start.unwrap());
}

#[test]
fn local_definition_comes_first() {
    let (_dir, engine) = engine();
    let open = engine
        .open_session("buf".into(), None, TEXT.into(), None)
        .unwrap();
    let resp = engine.find_definitions(open.session_id, byte_of("helper();", 0));
    let hit = &resp.hits[0];
    assert_eq!(hit.name, "helper");
    assert!(hit.source_path.is_none());
    assert_eq!(hit.byte_start, Some(TEXT.find("fn helper").unwrap() as u32));
}

#[test]
fn qualified_path_narrows_hits() {
    let (_dir, engine) = engine();
    let open = engine
        .open_session("buf".into(), None, TEXT.into(), None)
        .unwrap();
    let resp = engine.find_definitions(open.session_id, byte_of("HashSet", 0));
    let symbol = resp.symbol.expect("symbol");
    assert_eq!(symbol.qualifier.as_deref(), Some("std::collections"));
    assert_eq!(resp.hits[0].path, "std::collections::HashSet");
}

#[test]
fn whitespace_has_no_symbol() {
    let (_dir, engine) = engine();
    let open = engine
        .open_session("buf".into(), None, TEXT.into(), None)
        .unwrap();
    let resp = engine.find_definitions(open.session_id, byte_of("{\n    let m", 0) + 2);
    assert!(resp.symbol.is_none());
    assert!(resp.hits.is_empty());
}
