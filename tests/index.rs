use std::path::PathBuf;

use ride_engine::{EngineConfig, IndexState, SCHEMA_VERSION, read_manifest, write_index};
use tantivy::Index;

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

#[test]
fn writes_staging_then_gen_and_manifest() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    let status = write_index(&project, dir.path(), &config(dir.path())).unwrap();
    assert_eq!(status.state, IndexState::Ready);
    assert!(status.docs > 0);
    let manifest = read_manifest(dir.path()).expect("manifest");
    assert_eq!(manifest.schema_version, SCHEMA_VERSION);
    assert_eq!(manifest.generation, 1);
    assert_eq!(manifest.live_dir, "gen-1");
    let live = dir.path().join("gen-1");
    assert!(live.is_dir());
    assert!(
        !dir.path()
            .join(format!("staging-{}", std::process::id()))
            .exists()
    );
    let index = Index::open_in_dir(&live).unwrap();
    let reader = index.reader().unwrap();
    assert_eq!(reader.searcher().num_docs(), u64::from(status.docs));
}

#[test]
fn second_index_bumps_generation() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    write_index(&project, dir.path(), &config(dir.path())).unwrap();
    write_index(&project, dir.path(), &config(dir.path())).unwrap();
    let manifest = read_manifest(dir.path()).unwrap();
    assert_eq!(manifest.generation, 2);
    assert_eq!(manifest.live_dir, "gen-2");
    assert!(dir.path().join("gen-2").is_dir());
}

#[test]
fn catalog_drops_private_of_cache_crate() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("workspace");
    let status = write_index(&project, dir.path(), &config(dir.path())).unwrap();
    assert_eq!(status.state, IndexState::Ready);
    let index = Index::open_in_dir(dir.path().join("gen-1")).unwrap();
    let schema = index.schema();
    let name = schema.get_field("name_exact").unwrap();
    let searcher = index.reader().unwrap().searcher();
    let query = tantivy::query::TermQuery::new(
        tantivy::Term::from_field_text(name, "demo"),
        tantivy::schema::IndexRecordOption::Basic,
    );
    let hits = searcher
        .search(&query, &tantivy::collector::TopDocs::with_limit(10))
        .unwrap();
    assert!(!hits.is_empty());
}
