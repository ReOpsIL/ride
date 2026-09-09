use std::path::PathBuf;

use ride_engine::{
    EngineConfig, IndexState, SCHEMA_VERSION, last_status, read_manifest, rebuild_index,
    write_index,
};
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
fn rebuild_bumps_generation() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    write_index(&project, dir.path(), &config(dir.path())).unwrap();
    rebuild_index(&project, dir.path(), &config(dir.path())).unwrap();
    let manifest = read_manifest(dir.path()).unwrap();
    assert_eq!(manifest.generation, 2);
    assert_eq!(manifest.live_dir, "gen-2");
    assert!(dir.path().join("gen-2").is_dir());
}

#[test]
fn unchanged_crate_set_skips_reindex() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    let first = write_index(&project, dir.path(), &config(dir.path())).unwrap();
    let second = write_index(&project, dir.path(), &config(dir.path())).unwrap();
    let manifest = read_manifest(dir.path()).unwrap();
    assert_eq!(manifest.generation, 1);
    assert!(!manifest.fingerprint.is_empty());
    assert_eq!(second.state, IndexState::Ready);
    assert_eq!(second.docs, first.docs);
    assert_eq!(second.crates_done, second.crates_total);
    assert!(!dir.path().join("gen-2").exists());
    let disk = last_status(dir.path()).unwrap();
    assert_eq!(disk.state, IndexState::Ready);
    assert_eq!(disk.docs, first.docs);
}

#[test]
fn prunes_generations_older_than_previous() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    for _ in 0..3 {
        rebuild_index(&project, dir.path(), &config(dir.path())).unwrap();
    }
    assert!(!dir.path().join("gen-1").exists());
    assert!(dir.path().join("gen-2").is_dir());
    assert!(dir.path().join("gen-3").is_dir());
    assert_eq!(read_manifest(dir.path()).unwrap().live_dir, "gen-3");
}

#[test]
fn crate_errors_go_to_warnings_log_not_status() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    let status = write_index(&project, dir.path(), &config(dir.path())).unwrap();
    assert!(status.message.is_none());
    let log = std::fs::read_to_string(dir.path().join("warnings.jsonl")).unwrap();
    assert_eq!(log.lines().count() as u32, status.warnings);
    let lines = std::fs::read_to_string(dir.path().join("status.jsonl")).unwrap();
    assert!(!lines.contains("missing [package]"));
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

fn copy_dir(from: &std::path::Path, to: &std::path::Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap().flatten() {
        let dest = to.join(entry.file_name());
        if entry.path().is_dir() {
            copy_dir(&entry.path(), &dest);
        } else {
            std::fs::copy(entry.path(), dest).unwrap();
        }
    }
}

fn count_named(index_dir: &std::path::Path, name: &str) -> usize {
    let live = index_dir.join(read_manifest(index_dir).unwrap().live_dir);
    let index = Index::open_in_dir(live).unwrap();
    let field = index.schema().get_field("name_exact").unwrap();
    let searcher = index.reader().unwrap().searcher();
    let query = tantivy::query::TermQuery::new(
        tantivy::Term::from_field_text(field, name),
        tantivy::schema::IndexRecordOption::Basic,
    );
    searcher.search(&query, &tantivy::collector::Count).unwrap()
}

#[test]
fn workspace_edit_reindexes_only_the_workspace_crate() {
    let dir = tempfile::tempdir().unwrap();
    let project = dir.path().join("proj");
    copy_dir(&fixtures().join("sample_crate"), &project);
    let index_dir = dir.path().join("index");
    let first = write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    assert!(first.crates_total > 1);
    assert_eq!(count_named(&index_dir, "added_fn"), 0);
    let hashmap_before = count_named(&index_dir, "hashmap");
    let lib = project.join("src/lib.rs");
    let mut text = std::fs::read_to_string(&lib).unwrap();
    text.push_str("\npub fn added_fn() {}\n");
    std::thread::sleep(std::time::Duration::from_millis(20));
    std::fs::write(&lib, text).unwrap();
    let second = write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    assert_eq!(second.state, IndexState::Ready);
    assert_eq!(
        second.crates_total, 1,
        "only the workspace crate is re-extracted"
    );
    assert_eq!(second.docs, first.docs + 1);
    assert_eq!(read_manifest(&index_dir).unwrap().generation, 2);
    assert_eq!(count_named(&index_dir, "added_fn"), 1);
    assert_eq!(count_named(&index_dir, "foo"), 1);
    assert_eq!(count_named(&index_dir, "hashmap"), hashmap_before);
}

#[test]
fn removed_workspace_item_disappears_after_incremental_reindex() {
    let dir = tempfile::tempdir().unwrap();
    let project = dir.path().join("proj");
    copy_dir(&fixtures().join("sample_crate"), &project);
    let index_dir = dir.path().join("index");
    write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    assert_eq!(count_named(&index_dir, "free_fn"), 1);
    let lib = project.join("src/lib.rs");
    let text = std::fs::read_to_string(&lib)
        .unwrap()
        .replace("pub fn free_fn() {}", "");
    std::thread::sleep(std::time::Duration::from_millis(20));
    std::fs::write(&lib, text).unwrap();
    let second = write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    assert_eq!(second.crates_total, 1);
    assert_eq!(count_named(&index_dir, "free_fn"), 0);
}
