use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use ride_engine::{EngineConfig, engine_start, write_index};

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

const TEXT: &str =
    "use std::collections::HashMap;\nfn main() { let m: HashMap<u8, u8> = HashMap::new(); }\n";

#[test]
fn a_failed_index_open_is_retried_on_the_next_tick() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    write_index(&project, dir.path(), &config(dir.path())).unwrap();
    let live = dir.path().join("gen-1");
    let parked = dir.path().join("parked");
    fs::rename(&live, &parked).unwrap();
    let engine = engine_start(config(dir.path()));
    let open = engine
        .open_session("buf".into(), None, TEXT.into(), None)
        .unwrap();
    let at = TEXT.find("HashMap<").unwrap() as u32 + 1;
    let resolves = || !engine.find_definitions(open.session_id, at).hits.is_empty();
    std::thread::sleep(Duration::from_millis(600));
    assert!(!resolves(), "catalog answered without an index");
    fs::rename(&parked, &live).unwrap();
    let deadline = Instant::now() + Duration::from_secs(5);
    while !resolves() && Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(50));
    }
    assert!(resolves(), "reader was never reopened");
}
