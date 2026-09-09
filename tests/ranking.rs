use std::path::PathBuf;
use std::sync::Arc;

use ride_engine::{
    CompletionQuery, Engine, EngineConfig, ItemKind, QueryMode, engine_start, write_index,
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
    (dir, engine)
}

fn names(engine: &Engine, prefix: &str) -> Vec<String> {
    engine
        .query_completions(CompletionQuery {
            query_id: 1,
            session_id: 0,
            prefix: prefix.into(),
            mode: QueryMode::Items,
            cursor_byte: 0,
            replace_start_byte: 0,
            current_crate: None,
            current_module: None,
            kind_filter: None,
            limit: 20,
        })
        .hits
        .iter()
        .map(|h| h.name.clone())
        .collect()
}

#[test]
fn hash_prefix_ranks_types_above_noise() {
    let (_dir, engine) = engine();
    let top = names(&engine, "has");
    assert_eq!(top.len(), 20, "{top:?}");
    let head: Vec<&str> = top.iter().take(3).map(String::as_str).collect();
    for expected in ["Hash", "HashMap", "HashSet"] {
        assert!(head.contains(&expected), "{top:?}");
    }
    assert!(
        !top[..5].iter().any(|n| n.starts_with("hash_noise")),
        "{top:?}"
    );
}

#[test]
fn uppercase_prefix_has_no_keywords() {
    let (_dir, engine) = engine();
    let resp = engine.query_completions(CompletionQuery {
        query_id: 1,
        session_id: 0,
        prefix: "Fo".into(),
        mode: QueryMode::Items,
        cursor_byte: 0,
        replace_start_byte: 0,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    });
    assert_eq!(resp.hits[0].name, "Foo");
    assert!(resp.hits.iter().all(|h| h.item_kind != ItemKind::Keyword));
}

#[test]
fn lowercase_prefix_keeps_keywords_first() {
    let (_dir, engine) = engine();
    let top = names(&engine, "st");
    assert!(top[..3].contains(&"struct".to_string()), "{top:?}");
    assert!(top[..3].contains(&"static".to_string()), "{top:?}");
}

#[test]
fn exact_name_wins_over_shorter_prefix_match() {
    let (_dir, engine) = engine();
    let top = names(&engine, "hashmap");
    assert_eq!(top[0], "HashMap", "{top:?}");
}

#[test]
fn workspace_before_sysroot_before_cache() {
    let (_dir, engine) = engine();
    let top = names(&engine, "free");
    assert_eq!(
        top[..3],
        [
            "free_fn".to_string(),
            "free_std".into(),
            "free_cache".into()
        ],
        "{top:?}"
    );
}

#[test]
fn prefix_longer_than_max_gram_still_matches() {
    let (_dir, engine) = engine();
    let top = names(&engine, "hash_noise_000000000000000");
    assert!(top.is_empty(), "{top:?}");
    let top = names(&engine, "hash_noise_01");
    assert_eq!(top.len(), 10, "{top:?}");
}
