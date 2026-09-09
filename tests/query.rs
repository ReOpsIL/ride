use std::path::PathBuf;
use std::time::{Duration, Instant};

use ride_engine::{
    CompletionContext, CompletionQuery, EngineConfig, ItemKind, QueryMode, engine_start,
    rebuild_index, write_index,
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

fn query(prefix: &str, mode: QueryMode) -> CompletionQuery {
    query_id(1, prefix, mode)
}

fn query_id(query_id: u64, prefix: &str, mode: QueryMode) -> CompletionQuery {
    CompletionQuery {
        query_id,
        session_id: 0,
        prefix: prefix.into(),
        mode,
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
fn prefix_finds_workspace_struct() {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    let resp = engine.query_completions(query("Foo", QueryMode::Items));
    assert!(
        resp.hits.iter().any(|h| h.name == "Foo"),
        "hits: {:?}",
        resp.hits.iter().map(|h| &h.name).collect::<Vec<_>>()
    );
}

#[test]
fn rustdoc_kind_filter() {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    let resp = engine.query_completions(query("fn:free", QueryMode::Items));
    assert!(
        resp.hits
            .iter()
            .any(|h| h.name == "free_fn" && h.item_kind == ItemKind::Fn),
        "hits: {:?}",
        resp.hits
            .iter()
            .map(|h| (&h.name, h.item_kind))
            .collect::<Vec<_>>()
    );
    let structs = engine.query_completions(query("struct:Foo", QueryMode::Items));
    assert!(structs.hits.iter().all(|h| h.item_kind == ItemKind::Struct));
    assert!(structs.hits.iter().any(|h| h.name == "Foo"));
}

#[test]
fn crate_prefix_mode() {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    let resp = engine.query_completions(query("sam", QueryMode::PrefixCrates));
    assert!(
        resp.hits
            .iter()
            .any(|h| h.item_kind == ItemKind::Crate && h.name == "sample"),
        "hits: {:?}",
        resp.hits.iter().map(|h| &h.name).collect::<Vec<_>>()
    );
}

#[test]
fn keywords_without_session() {
    let engine = engine_start(config(std::path::Path::new(".")));
    let resp = engine.query_completions(query("fn", QueryMode::BufferLocal));
    assert!(
        resp.hits
            .iter()
            .any(|h| h.name == "fn" && h.item_kind == ItemKind::Keyword)
    );
}

#[test]
fn query_is_fast_on_fixture() {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    let _ = engine.query_completions(query("Foo", QueryMode::Items));
    let start = Instant::now();
    let n = 20;
    for _ in 0..n {
        let _ = engine.query_completions(query("Foo", QueryMode::Items));
    }
    let p95ish = start.elapsed() / n;
    assert!(
        p95ish.as_millis() < 20,
        "mean query {:?} exceeds 20ms",
        p95ish
    );
}

#[test]
fn overlay_hides_source_path() {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    let before = engine.query_completions(query("Foo", QueryMode::Items));
    let path = before
        .hits
        .iter()
        .find(|h| h.name == "Foo")
        .and_then(|h| h.source_path.clone())
        .expect("source path");
    engine.workspace_file_changed(path);
    let after = engine.query_completions(query("Foo", QueryMode::Items));
    assert!(after.hits.iter().all(|h| h.name != "Foo"));
}

#[test]
fn watch_picks_up_new_generation() {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(config(dir.path()));
    let before = engine.query_completions(query("Foo", QueryMode::Items));
    assert!(before.hits.iter().all(|h| h.name != "Foo"));
    rebuild_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    std::thread::sleep(Duration::from_millis(450));
    let after = engine.query_completions(query("Foo", QueryMode::Items));
    assert!(
        after.hits.iter().any(|h| h.name == "Foo"),
        "hits: {:?}",
        after.hits.iter().map(|h| &h.name).collect::<Vec<_>>()
    );
}

#[test]
fn overlay_clears_on_new_generation() {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    let before = engine.query_completions(query("Foo", QueryMode::Items));
    let path = before
        .hits
        .iter()
        .find(|h| h.name == "Foo")
        .and_then(|h| h.source_path.clone())
        .expect("source path");
    engine.workspace_file_changed(path);
    assert!(
        engine
            .query_completions(query("Foo", QueryMode::Items))
            .hits
            .iter()
            .all(|h| h.name != "Foo")
    );
    rebuild_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    std::thread::sleep(Duration::from_millis(450));
    assert!(
        engine
            .query_completions(query("Foo", QueryMode::Items))
            .hits
            .iter()
            .any(|h| h.name == "Foo")
    );
}

#[test]
fn stale_query_id_is_dropped() {
    let dir = tempfile::tempdir().unwrap();
    write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    let engine = engine_start(config(dir.path()));
    let fresh = engine.query_completions(query_id(10, "Foo", QueryMode::Items));
    assert!(fresh.hits.iter().any(|h| h.name == "Foo"));
    let stale = engine.query_completions(query_id(1, "Foo", QueryMode::Items));
    assert!(stale.hits.is_empty());
    assert_eq!(stale.query_id, 1);
}
