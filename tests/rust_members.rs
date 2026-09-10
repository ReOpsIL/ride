use std::path::PathBuf;
use std::sync::Arc;

use ride_engine::{
    CompletionContext, CompletionQuery, CompletionResponse, CompletionSiteKind, Engine,
    EngineConfig, ItemKind, QueryMode, engine_start, write_index,
};

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
    engine
        .open_workspace(fixtures().join("sample_crate").display().to_string())
        .unwrap();
    (dir, engine)
}

fn complete(engine: &Engine, src: &str) -> CompletionResponse {
    let at = src.find('|').expect("caret");
    let text = src.replacen('|', "", 1);
    let open = engine
        .open_session("t".into(), Some("/w/src/lib.rs".into()), text, None)
        .unwrap();
    engine.query_completions(CompletionQuery {
        query_id: 1,
        session_id: open.session_id,
        prefix: String::new(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at as u32,
        replace_start_byte: at as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    })
}

fn names(resp: &CompletionResponse) -> Vec<String> {
    resp.hits.iter().map(|h| h.name.clone()).collect()
}

fn has(names: &[String], name: &str) -> bool {
    names.iter().any(|n| n == name)
}

fn kind_of(resp: &CompletionResponse, name: &str) -> Option<ItemKind> {
    resp.hits
        .iter()
        .find(|h| h.name == name)
        .map(|h| h.item_kind)
}

const FOO: &str = "struct Foo { x: i32, y: String }\nstruct Other { unrelated: u8 }\nimpl Foo {\n    fn area(&self) -> i32 { self.x }\n    fn grow(&mut self) {}\n}\n";

#[test]
fn self_lists_buffer_fields_and_methods_in_declaration_order() {
    let (_dir, engine) = engine();
    let src = format!("{FOO}impl Foo {{\n    fn probe(&self) {{ self.| }}\n}}\n");
    let resp = complete(&engine, &src);
    assert_eq!(resp.site, CompletionSiteKind::MemberAccess);
    let n = names(&resp);
    assert_eq!(&n[..5], &["x", "y", "area", "grow", "probe"], "{n:?}");
    assert_eq!(kind_of(&resp, "x"), Some(ItemKind::Field));
    assert_eq!(kind_of(&resp, "area"), Some(ItemKind::Method));
    assert!(has(&n, "new") && has(&n, "required"), "{n:?}");
    assert!(!has(&n, "unrelated"), "{n:?}");
}

#[test]
fn constructor_call_resolves_to_catalog_methods() {
    let (_dir, engine) = engine();
    let src = format!(
        "use std::collections::HashMap;\n{FOO}fn main() {{\n    let m = HashMap::new();\n    m.|\n}}\n"
    );
    let resp = complete(&engine, &src);
    let n = names(&resp);
    assert!(has(&n, "insert") && has(&n, "get"), "{n:?}");
    assert_eq!(kind_of(&resp, "insert"), Some(ItemKind::Method));
    assert!(!has(&n, "unrelated") && !has(&n, "x"), "{n:?}");
    let src = format!("{FOO}fn main() {{\n    let v = Vec::new();\n    v.|\n}}\n");
    let n = names(&complete(&engine, &src));
    assert!(has(&n, "push") && has(&n, "len"), "{n:?}");
    assert!(!has(&n, "unrelated"), "{n:?}");
    let src = format!("{FOO}fn main() {{\n    let v = vec![1];\n    v.|\n}}\n");
    let n = names(&complete(&engine, &src));
    assert!(has(&n, "push"), "{n:?}");
}

#[test]
fn annotated_local_merges_buffer_fields_with_catalog_methods() {
    let (_dir, engine) = engine();
    let src = format!("{FOO}fn main() {{\n    let f: Foo = Foo::new();\n    f.|\n}}\n");
    let resp = complete(&engine, &src);
    let n = names(&resp);
    assert_eq!(&n[..4], &["x", "y", "area", "grow"], "{n:?}");
    assert!(has(&n, "new") && has(&n, "required"), "{n:?}");
    assert_eq!(kind_of(&resp, "new"), Some(ItemKind::Method));
    assert!(!has(&n, "unrelated"), "{n:?}");
    let src =
        format!("{FOO}fn main() {{\n    let f = Foo {{ x: 1, y: String::new() }};\n    f.|\n}}\n");
    let n = names(&complete(&engine, &src));
    assert_eq!(&n[..2], &["x", "y"], "{n:?}");
}

#[test]
fn parameters_and_field_chains_resolve_through_declared_types() {
    let (_dir, engine) = engine();
    let src = "struct Point { x: f64, y: f64 }\nstruct Other { unrelated: u8 }\nfn f(p: &Point) { p.| }\n";
    let resp = complete(&engine, src);
    assert_eq!(names(&resp), vec!["x", "y"]);
    let src = "struct Point { x: f64, y: f64 }\nstruct Rect { origin: Point, w: f64 }\nimpl Rect {\n    fn f(&self) { self.origin.| }\n}\n";
    assert_eq!(names(&complete(&engine, src)), vec!["x", "y"]);
    let src = "struct Point { x: f64, y: f64 }\nstruct Rect { origin: Point, w: f64 }\nfn f(r: &mut Rect) { for q in 0..1 { let p = r.origin; p.| } }\n";
    assert_eq!(names(&complete(&engine, src)), vec!["x", "y"]);
}

#[test]
fn nearest_declaration_wins_and_shadowing_loses_the_type() {
    let (_dir, engine) = engine();
    let src = "struct Point { x: f64, y: f64 }\nstruct Rect { w: f64, h: f64 }\nfn f(p: &Point) { let p = Rect { w: 1.0, h: 2.0 }; p.| }\n";
    assert_eq!(names(&complete(&engine, src)), vec!["w", "h"]);
    let src = "struct Point { x: f64, y: f64 }\nfn g() {}\nfn f() { let q = g(); q.| }\n";
    let n = names(&complete(&engine, src));
    assert!(has(&n, "x") && has(&n, "y"), "{n:?}");
}

#[test]
fn struct_literal_lists_missing_fields_with_colon_insert() {
    let (_dir, engine) = engine();
    let src = "struct Foo { a: i32, b: i32, c: Vec<u8> }\nfn f() { let f = Foo { a: 1, | }; }\n";
    let resp = complete(&engine, src);
    assert_eq!(resp.site, CompletionSiteKind::StructLiteral);
    assert_eq!(names(&resp), vec!["b", "c"]);
    assert!(resp.hits.iter().all(|h| h.item_kind == ItemKind::Field));
    assert_eq!(resp.hits[0].insert_text, "b: ");
    let src = "struct Foo { a: i32, b: i32, c: Vec<u8> }\nfn f() { let f = Foo { c: vec![1, 2], b|: 2 }; }\n";
    let resp = complete(&engine, src);
    assert_eq!(names(&resp), vec!["b"]);
    assert_eq!(resp.hits[0].insert_text, "b");
    let src = "struct Foo { a: i32, b: i32 }\nimpl Foo { fn new() -> Self { Self { | } } }\n";
    assert_eq!(names(&complete(&engine, src)), vec!["a", "b"]);
}

#[test]
fn enum_paths_still_list_variants() {
    let (_dir, engine) = engine();
    let resp = complete(&engine, "fn f() { let e = E::| }");
    assert_eq!(resp.site, CompletionSiteKind::ScopedPath);
    let n = names(&resp);
    assert!(has(&n, "A") && has(&n, "B"), "{n:?}");
    assert_eq!(kind_of(&resp, "A"), Some(ItemKind::Variant));
}
