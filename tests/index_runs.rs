use std::path::{Path, PathBuf};

use ride_engine::{EngineConfig, IndexState, read_manifest, write_index};
use tantivy::Index;
use tantivy::collector::TopDocs;
use tantivy::query::TermQuery;
use tantivy::schema::{IndexRecordOption, TantivyDocument, Value};

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
        report_dir: None,
    }
}

fn copy_dir(from: &Path, to: &Path) {
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

fn stored_kind(index_dir: &Path, path_exact: &str) -> Option<String> {
    let live = index_dir.join(read_manifest(index_dir)?.live_dir);
    let index = Index::open_in_dir(live).ok()?;
    let schema = index.schema();
    let field = schema.get_field("path_exact").ok()?;
    let kind = schema.get_field("item_kind").ok()?;
    let searcher = index.reader().ok()?.searcher();
    let query = TermQuery::new(
        tantivy::Term::from_field_text(field, path_exact),
        IndexRecordOption::Basic,
    );
    let (_, addr) = *searcher
        .search(&query, &TopDocs::with_limit(1))
        .ok()?
        .first()?;
    let doc: TantivyDocument = searcher.doc(addr).ok()?;
    doc.get_first(kind)?.as_str().map(str::to_string)
}

#[test]
fn concurrent_runs_on_one_index_dir_both_succeed() {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    let index_dir = dir.path().join("index");
    let runs: Vec<_> = (0..3)
        .map(|_| {
            let project = project.clone();
            let index_dir = index_dir.clone();
            std::thread::spawn(move || write_index(&project, &index_dir, &config(&index_dir)))
        })
        .collect();
    for run in runs {
        let status = run.join().unwrap().unwrap();
        assert_eq!(status.state, IndexState::Ready);
    }
    let manifest = read_manifest(&index_dir).unwrap();
    assert_eq!(manifest.generation, 1);
    assert!(index_dir.join(&manifest.live_dir).is_dir());
}

#[test]
fn workspace_named_reexport_of_std_resolves_to_the_std_item() {
    let dir = tempfile::tempdir().unwrap();
    let project = dir.path().join("proj");
    copy_dir(&fixtures().join("sample_crate"), &project);
    let lib = project.join("src/lib.rs");
    let mut text = std::fs::read_to_string(&lib).unwrap();
    text.push_str("\npub use std::collections::HashSet as Set;\n");
    std::fs::write(&lib, text).unwrap();
    let index_dir = dir.path().join("index");
    write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    assert_eq!(
        stored_kind(&index_dir, "sample::set").as_deref(),
        Some("struct")
    );
}

#[test]
fn plain_folder_with_symlink_loops_indexes() {
    let dir = tempfile::tempdir().unwrap();
    let project = dir.path().join("loose");
    std::fs::create_dir_all(project.join("nested")).unwrap();
    std::fs::write(project.join("nested/lib.rs"), "pub fn loose_fn() {}\n").unwrap();
    std::os::unix::fs::symlink(&project, project.join("nested/up1")).unwrap();
    std::os::unix::fs::symlink(&project, project.join("nested/up2")).unwrap();
    let index_dir = dir.path().join("index");
    let status = write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    assert_eq!(status.state, IndexState::Ready);
    let warnings = std::fs::read_to_string(index_dir.join("warnings.jsonl")).unwrap_or_default();
    assert_eq!(
        stored_kind(&index_dir, "loose::loose_fn").as_deref(),
        Some("fn"),
        "{warnings}"
    );
}

#[test]
fn incremental_reindex_shares_segment_files_with_the_previous_generation() {
    use std::os::unix::fs::MetadataExt;
    let dir = tempfile::tempdir().unwrap();
    let project = dir.path().join("proj");
    copy_dir(&fixtures().join("sample_crate"), &project);
    let index_dir = dir.path().join("index");
    let first = write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    let lib = project.join("src/lib.rs");
    let mut text = std::fs::read_to_string(&lib).unwrap();
    text.push_str("\npub fn shared_links() {}\n");
    std::thread::sleep(std::time::Duration::from_millis(20));
    std::fs::write(&lib, text).unwrap();
    let second = write_index(&project, &index_dir, &config(&index_dir)).unwrap();
    assert_eq!(second.docs, first.docs + 1);
    let linked = std::fs::read_dir(index_dir.join("gen-2"))
        .unwrap()
        .flatten()
        .filter(|e| e.metadata().is_ok_and(|m| m.nlink() > 1))
        .count();
    assert!(linked > 0);
    let old = Index::open_in_dir(index_dir.join("gen-1")).unwrap();
    assert_eq!(
        old.reader().unwrap().searcher().num_docs(),
        u64::from(first.docs)
    );
}
