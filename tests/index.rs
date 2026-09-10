use std::path::PathBuf;

use ride_engine::{
    DEPRECATED, EngineConfig, IndexState, NAME_HUMP, PARENT_PATH, REACHABLE, SCHEMA_VERSION, hump,
    last_status, parent_path_of, read_manifest, rebuild_index, write_index,
};
use tantivy::collector::TopDocs;
use tantivy::query::TermQuery;
use tantivy::schema::{IndexRecordOption, TantivyDocument, Value};
use tantivy::{DocAddress, Index, Term};

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

fn indexed_sample() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    let project = fixtures().join("sample_crate");
    write_index(&project, dir.path(), &config(dir.path())).unwrap();
    dir
}

fn live_index(index_dir: &std::path::Path) -> Index {
    let live = index_dir.join(read_manifest(index_dir).unwrap().live_dir);
    Index::open_in_dir(live).unwrap()
}

fn term_hits(index: &Index, field: &str, value: &str) -> Vec<DocAddress> {
    let field = index.schema().get_field(field).unwrap();
    let searcher = index.reader().unwrap().searcher();
    let query = TermQuery::new(
        Term::from_field_text(field, value),
        IndexRecordOption::Basic,
    );
    searcher
        .search(&query, &TopDocs::with_limit(200))
        .unwrap()
        .into_iter()
        .map(|(_, addr)| addr)
        .collect()
}

fn stored(index: &Index, addr: DocAddress, field: &str) -> String {
    let searcher = index.reader().unwrap().searcher();
    let field = index.schema().get_field(field).unwrap();
    let doc: TantivyDocument = searcher.doc(addr).unwrap();
    doc.get_first(field)
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string()
}

fn names_under(index: &Index, field: &str, value: &str) -> Vec<String> {
    term_hits(index, field, value)
        .into_iter()
        .map(|addr| stored(index, addr, "name"))
        .collect()
}

fn fast_u64(index: &Index, path_exact: &str, field: &str) -> u64 {
    let addr = term_hits(index, "path_exact", path_exact)
        .into_iter()
        .next()
        .unwrap_or_else(|| panic!("missing {path_exact}"));
    let searcher = index.reader().unwrap().searcher();
    let column = searcher
        .segment_reader(addr.segment_ord)
        .fast_fields()
        .u64(field)
        .unwrap();
    column.first(addr.doc_id).unwrap()
}

#[test]
fn parent_path_lists_direct_children() {
    let dir = indexed_sample();
    let index = live_index(dir.path());
    let kids = names_under(&index, PARENT_PATH, "std::collections");
    for expected in [
        "HashMap",
        "HashSet",
        "Hash",
        "hash_map",
        "hash_slice",
        "free_std",
    ] {
        assert!(kids.contains(&expected.to_string()), "{kids:?}");
    }
    assert!(!kids.contains(&"map".to_string()), "{kids:?}");
    let assoc = names_under(&index, PARENT_PATH, "foo");
    for expected in ["new", "hidden", "required"] {
        assert!(assoc.contains(&expected.to_string()), "{assoc:?}");
    }
    let roots = names_under(&index, PARENT_PATH, "");
    for expected in ["sample", "std", "core", "demo"] {
        assert!(roots.contains(&expected.to_string()), "{roots:?}");
    }
    assert_eq!(
        parent_path_of("std::collections::HashMap"),
        "std::collections"
    );
    assert_eq!(parent_path_of("Type::method"), "type");
    assert_eq!(parent_path_of("std"), "");
}

#[test]
fn hump_strings() {
    assert_eq!(hump("HashMap"), "hm");
    assert_eq!(hump("read_line"), "rl");
    assert_eq!(hump("TokenStream"), "ts");
    assert_eq!(hump("HasLen"), "hl");
    assert_eq!(hump("Utf8Error"), "ue");
    assert_eq!(hump("IoSlice"), "is");
    assert_eq!(hump("Foo"), "f");
    assert_eq!(hump("hash_noise_000"), "hn");
}

#[test]
fn name_hump_matches_initials() {
    let dir = indexed_sample();
    let index = live_index(dir.path());
    let hm = names_under(&index, NAME_HUMP, "hm");
    assert!(hm.contains(&"HashMap".to_string()), "{hm:?}");
    assert!(!hm.contains(&"HashSet".to_string()), "{hm:?}");
    let hs = names_under(&index, NAME_HUMP, "hs");
    assert!(hs.contains(&"HashSet".to_string()), "{hs:?}");
    let f = names_under(&index, NAME_HUMP, "f");
    assert!(f.contains(&"free_fn".to_string()), "{f:?}");
    assert!(!f.contains(&"Foo".to_string()), "{f:?}");
}

#[test]
fn reachable_marks_private_module_chains() {
    let dir = indexed_sample();
    let index = live_index(dir.path());
    assert_eq!(fast_u64(&index, "std::sys::pal::token_query", REACHABLE), 0);
    assert_eq!(fast_u64(&index, "std::collections::hashmap", REACHABLE), 1);
    assert_eq!(
        fast_u64(&index, "std::collections::hash::map::hashmap", REACHABLE),
        0
    );
    assert_eq!(fast_u64(&index, "core::hash::hash", REACHABLE), 1);
    assert_eq!(fast_u64(&index, "demo::surfaced", REACHABLE), 1);
    assert_eq!(fast_u64(&index, "demo::inner::deep::buried", REACHABLE), 0);
    assert_eq!(
        fast_u64(&index, "sample::private_mod::only_in_private", REACHABLE),
        1
    );
}

#[test]
fn deprecated_flag_is_a_fast_field() {
    let dir = indexed_sample();
    let index = live_index(dir.path());
    assert_eq!(fast_u64(&index, "demo::old_demo", DEPRECATED), 1);
    assert_eq!(fast_u64(&index, "demo::demo", DEPRECATED), 0);
}

#[test]
fn cfg_test_items_are_not_indexed() {
    let dir = indexed_sample();
    assert_eq!(count_named(dir.path(), "in_tests"), 0);
    assert_eq!(count_named(dir.path(), "old_demo"), 1);
}

#[test]
fn enum_variants_are_indexed() {
    let dir = indexed_sample();
    let index = live_index(dir.path());
    for path in ["option::some", "option::none", "result::ok", "result::err"] {
        let addr = term_hits(&index, "path_exact", path)
            .into_iter()
            .next()
            .unwrap_or_else(|| panic!("missing {path}"));
        assert_eq!(stored(&index, addr, "item_kind"), "variant");
    }
    let kids = names_under(&index, PARENT_PATH, "option");
    assert!(kids.contains(&"Some".to_string()), "{kids:?}");
    assert!(kids.contains(&"None".to_string()), "{kids:?}");
    let some = term_hits(&index, "path_exact", "option::some")[0];
    assert_eq!(stored(&index, some, "signature"), "Some(T)");
    assert_eq!(fast_u64(&index, "option::some", REACHABLE), 1);
}
