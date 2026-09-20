use std::hint::black_box;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, Instant};

use ride_engine::{
    BufferSession, CompletionContext, CompletionQuery, Engine, EngineConfig, Lang, QueryMode,
    engine_start, write_index,
};

const WARMUP: usize = 5;
const RUNS: usize = 50;

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn fixtures() -> PathBuf {
    root().join("tests/fixtures")
}

fn config(index_dir: &Path) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: Some(fixtures().join("cargo_home").display().to_string()),
        sysroot: Some(fixtures().join("sysroot").display().to_string()),
        offline_metadata: true,
        refs_dir: None,
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

fn p95(times: &mut [Duration]) -> Duration {
    times.sort();
    times[(times.len() * 95 / 100).min(times.len() - 1)]
}

fn measure(mut body: impl FnMut()) -> Duration {
    for _ in 0..WARMUP {
        body();
    }
    let mut times = Vec::with_capacity(RUNS);
    for _ in 0..RUNS {
        let start = Instant::now();
        body();
        times.push(start.elapsed());
    }
    p95(&mut times)
}

fn completion_query(session_id: u64, query_id: u64, at: u32) -> CompletionQuery {
    CompletionQuery {
        query_id,
        session_id,
        prefix: String::new(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at,
        replace_start_byte: at,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    }
}

fn complete_p95(engine: &Engine, path: &Path, after: &str, typed: &str) -> Duration {
    let src = std::fs::read_to_string(path).unwrap();
    let start = src.find(after).unwrap_or_else(|| panic!("{after}"));
    let mut text = src;
    let mut at = start + after.len();
    text.insert_str(at, typed);
    at += typed.len();
    let open = engine
        .open_session("t".into(), Some(path.display().to_string()), text, None)
        .unwrap();
    let mut query_id = 0u64;
    measure(|| {
        query_id += 1;
        let resp = engine.query_completions(completion_query(open.session_id, query_id, at as u32));
        black_box(resp.hits.len());
    })
}

#[cfg_attr(debug_assertions, ignore)]
#[test]
fn completion_p95_under_5ms_per_site() {
    let (_dir, engine) = engine();
    let sites = [
        (
            "identifier",
            "tests/fixtures/sample_crate/src/lib.rs",
            "    pub fn new() -> Self {\n        ",
            "Has",
        ),
        (
            "member_access",
            "tests/fixtures/sample_crate/src/lib.rs",
            "fn required(&self) {",
            " self.",
        ),
        (
            "use_path",
            "tests/fixtures/sample_crate/src/lib.rs",
            "//! Sample crate inner docs.\n\n",
            "use std::",
        ),
        ("include", "samples/c-demo/src/main.c", "#include \"", ""),
        (
            "struct_literal",
            "tests/fixtures/sample_crate/src/lib.rs",
            "        Self {",
            "",
        ),
    ];
    for (name, rel, after, typed) in sites {
        let got = complete_p95(&engine, &root().join(rel), after, typed);
        println!("{name} p95 {got:?}");
        assert!(
            got < Duration::from_millis(5),
            "{name} p95 {got:?} exceeds 5ms"
        );
    }
}

#[cfg_attr(debug_assertions, ignore)]
#[test]
fn editor_queries_p95_under_1ms() {
    let text = std::fs::read_to_string(root().join("samples/rust-demo/src/main.rs")).unwrap();
    let (session, _) = BufferSession::open_lang(Lang::Rust, text, None).unwrap();
    let highlight = measure(|| {
        black_box(session.highlights().len());
    });
    let outline = measure(|| {
        black_box(session.outline_items().len());
    });
    println!("highlight p95 {highlight:?}");
    println!("outline p95 {outline:?}");
    assert!(
        highlight < Duration::from_millis(1),
        "highlight p95 {highlight:?} exceeds 1ms"
    );
    assert!(
        outline < Duration::from_millis(1),
        "outline p95 {outline:?} exceeds 1ms"
    );
}
