use std::path::{Path, PathBuf};

use ride_engine::{EngineConfig, live_index_dir, write_index};

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
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

fn dir_bytes(path: &Path) -> u64 {
    let mut total = 0;
    let Ok(entries) = std::fs::read_dir(path) else {
        return 0;
    };
    for entry in entries.flatten() {
        let child = entry.path();
        let Ok(meta) = entry.metadata() else {
            continue;
        };
        if meta.is_dir() {
            total += dir_bytes(&child);
        } else {
            total += meta.len();
        }
    }
    total
}

#[test]
fn fixture_index_bytes_per_document() {
    let dir = tempfile::tempdir().unwrap();
    let status = write_index(
        &fixtures().join("sample_crate"),
        dir.path(),
        &config(dir.path()),
    )
    .unwrap();
    assert!(status.docs > 0);
    let live = live_index_dir(dir.path()).expect("live index");
    let bytes = dir_bytes(&live);
    let per = bytes as f64 / f64::from(status.docs);
    println!("docs {} bytes {} bytes/doc {:.1}", status.docs, bytes, per);
    assert!(per < 600.0, "bytes/doc {per:.1} exceeds 600");
}
