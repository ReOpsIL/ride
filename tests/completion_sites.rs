use std::fs;
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

fn complete(engine: &Engine, path: &str, src: &str) -> CompletionResponse {
    let at = src.find('|').expect("caret");
    let text = src.replacen('|', "", 1);
    let open = engine
        .open_session("t".into(), Some(path.into()), text, None)
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

fn names(resp: &CompletionResponse) -> Vec<&str> {
    resp.hits.iter().map(|h| h.name.as_str()).collect()
}

#[test]
fn use_lists_crates_then_children() {
    let (_dir, engine) = engine();
    let resp = complete(&engine, "/w/src/lib.rs", "use |");
    assert_eq!(resp.site, CompletionSiteKind::UsePath);
    assert_eq!(resp.replace_start_byte, 4);
    let n = names(&resp);
    for expected in ["sample", "std", "core", "demo", "crate", "self", "super"] {
        assert!(n.contains(&expected), "{n:?}");
    }
    assert!(
        resp.hits
            .iter()
            .any(|h| h.name == "std" && h.item_kind == ItemKind::Crate)
    );
    let resp = complete(&engine, "/w/src/lib.rs", "use s|");
    let n = names(&resp);
    assert!(
        n.contains(&"std") && n.contains(&"sample") && n.contains(&"self"),
        "{n:?}"
    );
    assert!(!n.contains(&"demo"), "{n:?}");
    let resp = complete(&engine, "/w/src/lib.rs", "use std::|");
    let n = names(&resp);
    assert!(n.contains(&"collections"), "{n:?}");
    assert!(n.contains(&"self") && n.contains(&"*"), "{n:?}");
    let resp = complete(&engine, "/w/src/lib.rs", "use std::collections::Ha|");
    let n = names(&resp);
    assert!(
        n.contains(&"HashMap") && n.contains(&"HashSet") && n.contains(&"Hash"),
        "{n:?}"
    );
    let pos = |name: &str| n.iter().position(|x| *x == name).unwrap_or(usize::MAX);
    assert!(pos("HashMap") < pos("hash_slice"), "{n:?}");
    assert_eq!(resp.replace_start_byte, 22);
    let resp = complete(&engine, "/w/src/lib.rs", "use std::{io, collections::{|");
    let n = names(&resp);
    assert!(n.contains(&"HashMap") && n.contains(&"free_std"), "{n:?}");
}

#[test]
fn scoped_paths_list_children_and_associated_items() {
    let (_dir, engine) = engine();
    let resp = complete(
        &engine,
        "/w/src/lib.rs",
        "fn f() { let m = std::collections::|",
    );
    assert_eq!(resp.site, CompletionSiteKind::ScopedPath);
    let n = names(&resp);
    assert!(n.contains(&"HashMap") && n.contains(&"hash_slice"), "{n:?}");
    assert!(!n.contains(&"self"), "{n:?}");
    let resp = complete(&engine, "/w/src/lib.rs", "fn f() { Foo::|");
    let n = names(&resp);
    assert!(n.contains(&"new"), "{n:?}");
}

#[test]
fn identifiers_merge_locals_keywords_and_catalog() {
    let (_dir, engine) = engine();
    let resp = complete(
        &engine,
        "/w/src/lib.rs",
        "fn main() { let counter = 1; let x = cou| }",
    );
    assert_eq!(resp.site, CompletionSiteKind::Identifier);
    let n = names(&resp);
    assert_eq!(n.first(), Some(&"counter"), "{n:?}");
    let resp = complete(&engine, "/w/src/lib.rs", "fn main() { let f = Fo| }");
    let foo = resp
        .hits
        .iter()
        .find(|h| h.name == "Foo")
        .expect("catalog Foo");
    assert_eq!(foo.item_kind, ItemKind::Struct);
    assert!(
        foo.import_path
            .as_deref()
            .is_some_and(|p| p.ends_with("::Foo"))
    );
    assert!(
        !resp.hits.iter().any(|h| h.name == "for"),
        "{:?}",
        names(&resp)
    );
    let resp = complete(&engine, "/w/src/lib.rs", "fn main() { let f = fo| }");
    assert!(
        resp.hits
            .iter()
            .any(|h| h.name == "for" && h.item_kind == ItemKind::Keyword)
    );
    let resp = complete(
        &engine,
        "/w/src/lib.rs",
        "use sample::Foo;\nfn main() { let f = Fo| }",
    );
    let foo = resp.hits.iter().find(|h| h.name == "Foo").unwrap();
    assert!(foo.import_path.is_none());
}

#[test]
fn attributes_derives_and_c_directives() {
    let (_dir, engine) = engine();
    let resp = complete(&engine, "/w/src/lib.rs", "#[derive(Cl|");
    assert_eq!(resp.site, CompletionSiteKind::Attribute);
    assert_eq!(names(&resp), vec!["Clone"]);
    let resp = complete(&engine, "/w/src/lib.rs", "#[de|");
    let n = names(&resp);
    assert!(n.contains(&"derive") && n.contains(&"deprecated"), "{n:?}");
    let resp = complete(&engine, "/w/x.c", "#inc|");
    assert_eq!(resp.site, CompletionSiteKind::Directive);
    assert_eq!(names(&resp), vec!["include"]);
    assert_eq!(resp.replace_start_byte, 1);
}

#[test]
fn include_sites_list_headers_from_project_dirs() {
    let (_dir, engine) = engine();
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    fs::create_dir_all(root.join("include/sys")).unwrap();
    fs::create_dir_all(root.join("build")).unwrap();
    fs::write(root.join("include/geometry.h"), "int g(void);\n").unwrap();
    fs::write(root.join("include/sys/types.h"), "typedef int t;\n").unwrap();
    fs::write(root.join("local.h"), "int l(void);\n").unwrap();
    fs::write(root.join("main.c"), "int main(void) { return 0; }\n").unwrap();
    let db = format!(
        "[{{\"directory\": \"{0}\", \"file\": \"main.c\", \"command\": \"cc -Iinclude -c main.c\"}}]",
        root.display()
    );
    fs::write(root.join("build/compile_commands.json"), db).unwrap();
    let main = root.join("main.c").display().to_string();
    let resp = complete(
        &engine,
        &main,
        "#include \"|\nint main(void) { return 0; }\n",
    );
    assert_eq!(resp.site, CompletionSiteKind::Include);
    let n = names(&resp);
    assert!(
        n.contains(&"local.h") && n.contains(&"geometry.h") && n.contains(&"sys/"),
        "{n:?}"
    );
    assert_eq!(n.first(), Some(&"local.h"), "{n:?}");
    let resp = complete(&engine, &main, "#include <sys/ty|\n");
    assert_eq!(names(&resp), vec!["types.h"]);
    assert_eq!(resp.replace_start_byte, 14);
    let header = resp.hits[0].source_path.as_deref().unwrap();
    assert!(header.ends_with("include/sys/types.h"), "{header}");
}
