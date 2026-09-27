use std::path::PathBuf;
use std::sync::Arc;

use ride_engine::{
    CompletionContext, CompletionQuery, Engine, EngineConfig, QueryMode, engine_start, write_index,
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
        refs_dir: None,
        report_dir: None,
    }
}

fn engine() -> (tempfile::TempDir, Arc<Engine>) {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    write_index(&project, dir.path(), &config(dir.path())).unwrap();
    let engine = engine_start(config(dir.path()));
    engine
        .open_workspace(project.display().to_string())
        .unwrap();
    (dir, engine)
}

fn open(engine: &Engine, src: &str) -> (u64, u32) {
    let at = src.find('|').expect("caret");
    let text = src.replacen('|', "", 1);
    let open = engine
        .open_session("t".into(), Some("/w/src/main.rs".into()), text, None)
        .unwrap();
    (open.session_id, at as u32)
}

fn phrase(text: &str) -> CompletionQuery {
    CompletionQuery {
        query_id: 1,
        session_id: 0,
        prefix: text.into(),
        mode: QueryMode::Phrase,
        context: CompletionContext::Unknown,
        cursor_byte: 0,
        replace_start_byte: 0,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    }
}

#[test]
fn qualifier_matches_whole_path_segments_only() {
    let (_dir, engine) = engine();
    let (id, at) = open(&engine, "fn main() { let m = Map::new(|); }\n");
    let help = engine.signature_help(id, at);
    assert!(help.is_none(), "{help:?}");
    let (id, at) = open(&engine, "fn main() { let m = HashMap::new(|); }\n");
    let help = engine.signature_help(id, at).expect("hashmap new");
    assert_eq!(help.name, "new");
}

#[test]
fn phrase_with_path_separator_still_searches() {
    let (_dir, engine) = engine();
    let resp = engine.query_completions(phrase("collections::HashMap"));
    assert!(
        resp.hits.iter().any(|h| h.name == "HashMap"),
        "{:?}",
        resp.hits.iter().map(|h| &h.path).collect::<Vec<_>>()
    );
}

#[test]
fn generic_bounds_with_fn_traits_do_not_hide_parameters() {
    let (_dir, engine) = engine();
    let src = "fn apply<F: Fn(i32) -> i32>(f: F, x: i32) -> i32 { f(x) }\nfn main() { apply(|) }\n";
    let (id, at) = open(&engine, src);
    let help = engine.signature_help(id, at).expect("apply");
    assert_eq!(help.parameters.len(), 2, "{help:?}");
    let first = &help.parameters[0];
    assert_eq!(
        &help.label[first.start_byte as usize..first.end_byte as usize],
        "f: F"
    );
}
