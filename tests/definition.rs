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
    let src = std::fs::read_to_string(hit.source_path.as_deref().unwrap()).unwrap();
    let at = hit.name_byte.expect("name_byte") as usize;
    assert_eq!(src.get(at..at + hit.name.len()), Some("HashMap"));
    assert_ne!(hit.name_byte, hit.byte_start);
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
    assert_eq!(hit.name_byte, Some(TEXT.find("helper").unwrap() as u32));
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

fn fresh() -> (tempfile::TempDir, Arc<Engine>) {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: dir.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    (dir, engine)
}

fn excerpts(src: &str, path: &str, needle: &str) -> Vec<ride_engine::DefinitionExcerpt> {
    let (_dir, engine) = fresh();
    let open = engine
        .open_session("buf".into(), Some(path.into()), src.into(), None)
        .unwrap();
    let at = src.find(needle).expect(needle) as u32 + 1;
    engine.quick_definition(open.session_id, at)
}

#[test]
fn c_prototype_then_definition() {
    let src = "int add(int a, int b);\nint add(int a, int b) { return a + b; }\nint main(void) { return add(1, 2); }\n";
    let got = excerpts(src, "/tmp/t.c", "add(1");
    assert_eq!(got.len(), 2, "{got:?}");
    assert_eq!(got[0].label, "declaration");
    assert!(got[0].text.contains("int add(int a, int b);"));
    assert!(!got[0].text.contains('{'));
    assert_eq!(got[1].label, "definition");
    assert!(got[1].text.contains("return a + b"));
    assert!(!got[0].truncated && !got[1].truncated);
}

#[test]
fn rust_trait_method_two_impls() {
    let src = "trait Znarf { fn znarf(&self); }\nstruct ZA;\nstruct ZB;\nimpl Znarf for ZA { fn znarf(&self) {} }\nimpl Znarf for ZB { fn znarf(&self) {} }\nfn main() { let a = ZA; a.znarf(); }\n";
    let got = excerpts(src, "/tmp/t.rs", "znarf();");
    assert_eq!(got.len(), 3, "{got:?}");
    assert_eq!(got[0].label, "trait");
    assert!(got[0].text.contains("fn znarf(&self);"));
    assert_eq!(got[1].label, "impl for ZA");
    assert_eq!(got[2].label, "impl for ZB");
}

#[test]
fn long_function_is_truncated() {
    let mut src = String::from("fn huge() {\n");
    for i in 0..198 {
        src.push_str(&format!("    let v{i} = {i};\n"));
    }
    src.push_str("}\nfn main() { huge(); }\n");
    let got = excerpts(&src, "/tmp/t.rs", "huge();");
    assert_eq!(got.len(), 1, "{got:?}");
    assert!(got[0].truncated);
    assert_eq!(got[0].text.lines().count(), 60);
    assert!(got[0].text.starts_with("fn huge()"));
}

#[test]
fn catalog_hit_name_byte_is_identifier() {
    let (_dir, engine) = engine();
    let open = engine
        .open_session("buf".into(), None, TEXT.into(), None)
        .unwrap();
    let resp = engine.find_definitions(open.session_id, byte_of("HashMap<", 0));
    let hit = &resp.hits[0];
    let path = hit.source_path.clone().expect("source_path");
    let src = std::fs::read_to_string(&path).unwrap();
    let name_at = hit.name_byte.expect("name_byte");
    let at = name_at as usize;
    assert_eq!(src.get(at..at + hit.name.len()), Some("HashMap"));
    let src_open = engine
        .open_session("src".into(), Some(path), src, None)
        .unwrap();
    assert!(engine.quick_doc(src_open.session_id, name_at).is_some());
    assert!(
        engine
            .quick_doc(src_open.session_id, hit.byte_start.unwrap())
            .is_some()
    );
    assert!(
        !engine
            .quick_definition(src_open.session_id, hit.byte_start.unwrap())
            .is_empty()
    );
}

fn demo_engine() -> (tempfile::TempDir, Arc<Engine>, PathBuf) {
    let dir = tempfile::tempdir().unwrap();
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/rust-demo");
    write_index(&root, dir.path(), &config(dir.path())).unwrap();
    let engine = engine_start(config(dir.path()));
    engine.open_workspace(root.display().to_string()).unwrap();
    (dir, engine, root)
}

#[test]
fn workspace_counter_outranks_catalog_names() {
    let (_dir, engine, root) = demo_engine();
    let main = root.join("src/main.rs");
    let src = std::fs::read_to_string(&main).unwrap();
    let open = engine
        .open_session(
            "demo".into(),
            Some(main.display().to_string()),
            src.clone(),
            None,
        )
        .unwrap();
    let at = src.find("Counter::new()").unwrap() as u32 + 1;
    let resp = engine.find_definitions(open.session_id, at);
    let hit = resp.hits.first().expect("hit");
    assert_eq!(hit.name, "Counter");
    assert!(
        hit.source_path.as_deref().unwrap().ends_with("src/util.rs"),
        "{:?}",
        resp.hits
            .iter()
            .map(|h| (h.path.clone(), h.source_path.clone()))
            .collect::<Vec<_>>()
    );
    assert!(hit.path.ends_with("util::Counter"), "{}", hit.path);
    let excerpts = engine.quick_definition(open.session_id, at);
    let first = excerpts.first().expect("excerpt");
    assert!(first.path.ends_with("src/util.rs"), "{}", first.path);
    assert!(first.text.contains("pub struct Counter"), "{}", first.text);
}
