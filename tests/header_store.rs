use std::fs;
use std::time::{Duration, Instant};

use ride_engine::{EngineConfig, engine_start};

#[test]
fn engine_start_sweeps_header_summaries_of_older_formats() {
    let dir = tempfile::tempdir().unwrap();
    let store = dir.path().join("headers");
    fs::create_dir_all(&store).unwrap();
    let orphan = store.join("0123456789abcdef.json");
    let current = store.join("header-summary-v2-0123456789abcdef.json");
    fs::write(&orphan, "{}").unwrap();
    fs::write(&current, "{}").unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: dir.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    });
    let deadline = Instant::now() + Duration::from_secs(5);
    while orphan.exists() && Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(20));
    }
    assert!(!orphan.exists());
    assert!(current.exists());
    drop(engine);
}
