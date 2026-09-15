use std::path::{Path, PathBuf};

use ride_engine::{EngineConfig, IndexState, read_manifest, write_index};
use tantivy::Index;
use tantivy::collector::Count;
use tantivy::query::TermQuery;
use tantivy::schema::IndexRecordOption;

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn config(index_dir: &Path, cargo_home: &str) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: Some(fixtures().join(cargo_home).display().to_string()),
        sysroot: Some(fixtures().join("sysroot").display().to_string()),
        offline_metadata: true,
    }
}

fn count_path(index_dir: &Path, path: &str) -> usize {
    let live = index_dir.join(read_manifest(index_dir).unwrap().live_dir);
    let index = Index::open_in_dir(live).unwrap();
    let field = index.schema().get_field("path_exact").unwrap();
    let searcher = index.reader().unwrap().searcher();
    let query = TermQuery::new(
        tantivy::Term::from_field_text(field, &path.to_ascii_lowercase()),
        IndexRecordOption::Basic,
    );
    searcher.search(&query, &Count).unwrap()
}

fn indexed() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    let project = dir.path().join("proj");
    std::fs::create_dir_all(&project).unwrap();
    let index_dir = dir.path().join("index");
    let status = write_index(&project, &index_dir, &config(&index_dir, "facade_home")).unwrap();
    assert_eq!(status.state, IndexState::Ready);
    dir
}

#[test]
fn glob_target_items_keep_their_own_paths() {
    let dir = indexed();
    let index_dir = dir.path().join("index");
    assert_eq!(count_path(&index_dir, "leaf::net::Packet"), 1);
    assert_eq!(count_path(&index_dir, "leaf::net::proto::Kind"), 1);
}

#[test]
fn cross_crate_glob_mirrors_the_whole_subtree() {
    let dir = indexed();
    let index_dir = dir.path().join("index");
    assert_eq!(count_path(&index_dir, "facade::packet::LeafRoot"), 1);
    assert_eq!(count_path(&index_dir, "facade::packet::net"), 1);
    assert_eq!(count_path(&index_dir, "facade::packet::net::Packet"), 1);
    assert_eq!(count_path(&index_dir, "facade::packet::net::wrap"), 1);
    assert_eq!(
        count_path(&index_dir, "facade::packet::net::proto"),
        1,
        "a module two levels under the glob target is mirrored"
    );
    assert_eq!(
        count_path(&index_dir, "facade::packet::net::proto::Kind"),
        1,
        "an item three levels under the glob target is mirrored"
    );
}

#[test]
fn glob_resolves_whichever_crate_is_extracted_first() {
    let dir = indexed();
    let index_dir = dir.path().join("index");
    assert_eq!(
        count_path(&index_dir, "facade::packet::net::proto::Kind"),
        1,
        "facade sorts before leaf and still resolves"
    );
    assert_eq!(
        count_path(&index_dir, "zfacade::inner::net::proto::Kind"),
        1,
        "zfacade sorts after leaf and still resolves"
    );
}
