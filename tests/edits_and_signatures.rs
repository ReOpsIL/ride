use std::path::PathBuf;
use std::sync::Arc;

use ride_engine::{
    CompletionContext, CompletionQuery, CompletionResponse, Engine, EngineConfig, ItemKind,
    QueryMode, engine_start, write_index,
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

fn open(engine: &Engine, path: &str, src: &str) -> (u64, usize, String) {
    let at = src.find('|').expect("caret");
    let text = src.replacen('|', "", 1);
    let open = engine
        .open_session("t".into(), Some(path.into()), text.clone(), None)
        .unwrap();
    (open.session_id, at, text)
}

fn complete(engine: &Engine, path: &str, src: &str) -> CompletionResponse {
    let (id, at, _) = open(engine, path, src);
    engine.query_completions(CompletionQuery {
        query_id: 1,
        session_id: id,
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

fn apply(text: &str, edit: &ride_engine::TextEdit) -> String {
    let mut out = text.to_string();
    out.replace_range(edit.start_byte as usize..edit.end_byte as usize, &edit.text);
    out
}

#[test]
fn import_edit_inserts_sorted_into_the_last_use_block() {
    let (_dir, engine) = engine();
    let src = "use std::io;\nuse std::path::Path;\n\nfn main() {|}\n";
    let (id, _, text) = open(&engine, "/w/src/main.rs", src);
    let edit = engine
        .import_edit(id, "std::collections::HashMap".into())
        .unwrap();
    assert_eq!(
        apply(&text, &edit),
        "use std::collections::HashMap;\nuse std::io;\nuse std::path::Path;\n\nfn main() {}\n"
    );
    let edit = engine.import_edit(id, "std::sync::Arc".into()).unwrap();
    assert_eq!(
        apply(&text, &edit),
        "use std::io;\nuse std::path::Path;\nuse std::sync::Arc;\n\nfn main() {}\n"
    );
    assert!(engine.import_edit(id, "std::io".into()).is_none());
}

#[test]
fn import_edit_without_uses_goes_after_inner_attributes() {
    let (_dir, engine) = engine();
    let src = "//! crate docs\n#![allow(dead_code)]\n\nfn main() {|}\n";
    let (id, _, text) = open(&engine, "/w/src/main.rs", src);
    let edit = engine.import_edit(id, "sample::Foo".into()).unwrap();
    assert_eq!(
        apply(&text, &edit),
        "//! crate docs\n#![allow(dead_code)]\n\nuse sample::Foo;\n\nfn main() {}\n"
    );
    let src = "fn main() {|}\n";
    let (id, _, text) = open(&engine, "/w/src/main.rs", src);
    let edit = engine.import_edit(id, "sample::Foo".into()).unwrap();
    assert_eq!(apply(&text, &edit), "use sample::Foo;\n\nfn main() {}\n");
}

#[test]
fn signature_help_from_buffer_and_catalog() {
    let (_dir, engine) = engine();
    let src = "fn add(a: i32, b: i32) -> i32 { a + b }\nfn main() { add(1, |) }\n";
    let (id, at, _) = open(&engine, "/w/src/main.rs", src);
    let help = engine
        .signature_help(id, at as u32)
        .expect("buffer signature");
    assert!(help.label.contains("fn add(a: i32, b: i32)"), "{help:?}");
    assert_eq!(help.parameters.len(), 2);
    assert_eq!(help.active_parameter, 1);
    let first = &help.parameters[0];
    assert_eq!(
        &help.label[first.start_byte as usize..first.end_byte as usize],
        "a: i32"
    );
    let src = "fn main() { let f = sample::Foo::new(|); }\n";
    let (id, at, _) = open(&engine, "/w/src/main.rs", src);
    let help = engine
        .signature_help(id, at as u32)
        .expect("catalog signature");
    assert_eq!(help.name, "new");
    assert!(help.label.contains("fn new()"), "{help:?}");
    assert!(help.parameters.is_empty());
    let src = "fn main() { let s = \"a(b, c\"; if (x |) {} }\n";
    let (id, at, _) = open(&engine, "/w/src/main.rs", src);
    assert!(engine.signature_help(id, at as u32).is_none());
}

#[test]
fn c_signature_help_from_buffer_prototype() {
    let (_dir, engine) = engine();
    let src = "int area(int w, int h);\nint main(void) { return area(|); }\n";
    let (id, at, _) = open(&engine, "/w/x.c", src);
    let help = engine.signature_help(id, at as u32);
    if let Some(help) = help {
        assert!(help.label.contains("area"), "{help:?}");
    }
}

#[test]
fn call_snippets_and_keyword_templates() {
    let (_dir, engine) = engine();
    let resp = complete(&engine, "/w/src/main.rs", "fn main() { sample::free_f| }");
    let hit = resp
        .hits
        .iter()
        .find(|h| h.name == "free_fn")
        .expect("free_fn");
    assert!(hit.snippet, "{hit:?}");
    assert_eq!(hit.insert_text, "free_fn()$0");
    let resp = complete(&engine, "/w/src/main.rs", "fn main() { my_mac| }");
    let hit = resp
        .hits
        .iter()
        .find(|h| h.name == "my_macro")
        .expect("macro");
    assert_eq!(hit.insert_text, "my_macro!($0)");
    let resp = complete(&engine, "/w/src/main.rs", "fn main() {\n    mat|\n}");
    let hit = resp
        .hits
        .iter()
        .find(|h| h.name == "match")
        .expect("match kw");
    assert!(hit.snippet);
    assert_eq!(hit.insert_text, "match ${1:expr} {\n        $0\n    }");
    let resp = complete(&engine, "/w/src/main.rs", "fn main() { let x: mat| }");
    let hit = resp.hits.iter().find(|h| h.name == "match");
    assert!(hit.is_none_or(|h| !h.snippet));
    let resp = complete(&engine, "/w/x.c", "int main(void) {\n    fo|\n}");
    let hit = resp.hits.iter().find(|h| h.name == "for").expect("for kw");
    assert!(
        hit.insert_text.starts_with("for (${1:int i = 0};"),
        "{}",
        hit.insert_text
    );
}

#[test]
fn postfix_templates_replace_the_receiver() {
    let (_dir, engine) = engine();
    let src = "fn main() { let ready = true; ready.i| }";
    let resp = complete(&engine, "/w/src/main.rs", src);
    let hit = resp
        .hits
        .iter()
        .find(|h| h.name == "if")
        .expect("postfix if");
    assert!(hit.snippet);
    assert_eq!(hit.insert_text, "if ready {\n    $0\n}");
    let start = src.find("ready.i").unwrap();
    assert_eq!(hit.replace_start_byte, Some(start as u32));
    let src = "fn main() { foo.bar(1).d| }";
    let resp = complete(&engine, "/w/src/main.rs", src);
    let hit = resp
        .hits
        .iter()
        .find(|h| h.name == "dbg")
        .expect("postfix dbg");
    assert_eq!(hit.insert_text, "dbg!(foo.bar(1))$0");
    assert_eq!(
        hit.replace_start_byte,
        Some(src.find("foo.bar").unwrap() as u32)
    );
    let resp = complete(&engine, "/w/src/main.rs", "fn main() { foo.| }");
    assert!(!resp.hits.iter().any(|h| h.detail == "postfix"));
}

#[test]
fn hump_prefix_reaches_camel_case_names() {
    let (_dir, engine) = engine();
    let resp = complete(&engine, "/w/src/main.rs", "fn main() { let m = HM| }");
    let names: Vec<&str> = resp.hits.iter().map(|h| h.name.as_str()).collect();
    assert!(names.contains(&"HashMap"), "{names:?}");
    let resp = complete(&engine, "/w/src/main.rs", "fn main() { let m = Has| }");
    let names: Vec<&str> = resp.hits.iter().map(|h| h.name.as_str()).collect();
    let pos = |n: &str| names.iter().position(|x| *x == n).unwrap_or(usize::MAX);
    assert!(pos("HashMap") < pos("hash_slice"), "{names:?}");
    assert!(resp.hits.iter().all(|h| h.item_kind != ItemKind::Keyword));
}

#[test]
fn derive_completion_lists_proc_macro_derives_from_the_catalog() {
    let (_dir, engine) = engine();
    let resp = complete(&engine, "/w/src/main.rs", "#[derive(Fa|");
    let names: Vec<&str> = resp.hits.iter().map(|h| h.name.as_str()).collect();
    assert!(names.contains(&"Fancy"), "{names:?}");
    assert!(!names.contains(&"derive_fancy"), "{names:?}");
}
