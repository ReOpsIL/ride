use std::fs;
use std::path::{Path, PathBuf};

use ride_engine::includes::{IncludeRequest, complete};
use ride_engine::{CompletionHit, ItemKind};

struct Tree {
    dir: tempfile::TempDir,
}

impl Tree {
    fn new() -> Tree {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        for d in [
            "src/sub",
            "src/__hidden",
            "inc/sys",
            "sys",
            "fw/Foo.framework/Headers",
            "fw/Bar.txt",
        ] {
            fs::create_dir_all(root.join(d)).unwrap();
        }
        for f in [
            "src/main.c",
            "src/local.h",
            "src/Util.hpp",
            "src/notes.txt",
            "src/.hidden.h",
            "src/__private.h",
            "src/sub/inner.h",
            "inc/local.h",
            "inc/ext.h",
            "inc/sys/types.h",
            "inc/sys/stat.h",
            "sys/vector",
            "sys/stdio.h",
            "sys/__config",
            "sys/__locale",
            "fw/Foo.framework/Headers/Foo.h",
            "fw/Foo.framework/Headers/FooDefs.h",
        ] {
            fs::write(root.join(f), "").unwrap();
        }
        Tree { dir }
    }

    fn root(&self) -> &Path {
        self.dir.path()
    }

    fn complete(&self, quoted: bool, typed: &str, limit: usize) -> Vec<CompletionHit> {
        let file = self.root().join("src/main.c");
        let search_dirs = vec![self.root().join("inc")];
        let system_dirs = vec![
            (self.root().join("sys"), false),
            (self.root().join("fw"), true),
        ];
        complete(&IncludeRequest {
            quoted,
            typed,
            file: Some(&file),
            search_dirs: &search_dirs,
            system_dirs: &system_dirs,
            limit,
        })
    }
}

fn names(hits: &[CompletionHit]) -> Vec<&str> {
    hits.iter().map(|h| h.name.as_str()).collect()
}

fn find<'a>(hits: &'a [CompletionHit], name: &str) -> &'a CompletionHit {
    hits.iter()
        .find(|h| h.name == name)
        .unwrap_or_else(|| panic!("{name} missing in {:?}", names(hits)))
}

fn source(hit: &CompletionHit) -> PathBuf {
    PathBuf::from(hit.source_path.as_deref().unwrap())
}

#[test]
fn quoted_lists_the_including_file_dir_first_and_dedupes_by_name() {
    let tree = Tree::new();
    let hits = tree.complete(true, "", 50);
    let local = find(&hits, "local.h");
    assert_eq!(source(local), tree.root().join("src/local.h"));
    assert_eq!(
        local.signature,
        tree.root().join("src").display().to_string()
    );
    assert_eq!(local.item_kind, ItemKind::Header);
    assert_eq!(local.insert_text, "local.h");
    assert_eq!(local.path, "local.h");
    assert_eq!(hits.iter().filter(|h| h.name == "local.h").count(), 1);
    assert!(hits.iter().all(|h| h.crate_name.is_empty()));
    let listed = names(&hits);
    assert!(listed.contains(&"Util.hpp"), "{listed:?}");
    assert!(listed.contains(&"ext.h"), "{listed:?}");
    assert!(listed.contains(&"sys/"), "{listed:?}");
    assert!(!listed.contains(&"notes.txt"), "{listed:?}");
    assert!(!listed.contains(&".hidden.h"), "{listed:?}");
    assert!(!listed.contains(&"main.c"), "{listed:?}");
}

#[test]
fn angled_skips_the_including_file_dir() {
    let tree = Tree::new();
    let hits = tree.complete(false, "", 50);
    let listed = names(&hits);
    assert!(!listed.contains(&"Util.hpp"), "{listed:?}");
    assert!(!listed.contains(&"sub/"), "{listed:?}");
    assert_eq!(
        source(find(&hits, "local.h")),
        tree.root().join("inc/local.h")
    );
}

#[test]
fn sub_directory_lists_its_entries_with_the_full_relative_path() {
    let tree = Tree::new();
    let hits = tree.complete(false, "sys/t", 50);
    assert_eq!(names(&hits), ["types.h"]);
    assert_eq!(hits[0].path, "sys/types.h");
    assert_eq!(source(&hits[0]), tree.root().join("inc/sys/types.h"));
    let all = tree.complete(false, "sys/", 50);
    assert_eq!(names(&all), ["stat.h", "types.h"]);
}

#[test]
fn extension_less_headers_complete_as_files() {
    let tree = Tree::new();
    let hits = tree.complete(false, "vec", 50);
    assert_eq!(names(&hits), ["vector"]);
    assert_eq!(hits[0].item_kind, ItemKind::Header);
    assert_eq!(hits[0].insert_text, "vector");
}

#[test]
fn double_underscore_names_hide_until_an_underscore_is_typed() {
    let tree = Tree::new();
    let listed = names(&tree.complete(true, "", 100))
        .into_iter()
        .map(str::to_string)
        .collect::<Vec<_>>();
    assert!(!listed.iter().any(|n| n.starts_with("__")), "{listed:?}");
    let hits = tree.complete(true, "_", 100);
    let listed = names(&hits);
    assert!(listed.contains(&"__config"), "{listed:?}");
    assert!(listed.contains(&"__locale"), "{listed:?}");
    assert!(listed.contains(&"__private.h"), "{listed:?}");
    assert!(listed.contains(&"__hidden/"), "{listed:?}");
}

#[test]
fn directory_rows_end_with_a_slash_and_are_mods() {
    let tree = Tree::new();
    let hits = tree.complete(true, "su", 50);
    assert_eq!(names(&hits), ["sub/"]);
    assert_eq!(hits[0].insert_text, "sub/");
    assert_eq!(hits[0].path, "sub/");
    assert_eq!(hits[0].item_kind, ItemKind::Mod);
    assert_eq!(source(&hits[0]), tree.root().join("src/sub"));
}

#[test]
fn tiers_order_project_then_search_then_system_then_framework() {
    let tree = Tree::new();
    let hits = tree.complete(true, "", 100);
    let project = find(&hits, "Util.hpp").score;
    let search = find(&hits, "ext.h").score;
    let system = find(&hits, "stdio.h").score;
    let framework = find(&hits, "Foo/").score;
    assert!(project > search && search > system && system > framework);
    assert!(find(&hits, "local.h").score > find(&hits, "sub/").score);
    assert!(find(&hits, "ext.h").score > find(&hits, "sys/").score);
    let scores: Vec<f32> = hits.iter().map(|h| h.score).collect();
    assert!(scores.windows(2).all(|w| w[0] >= w[1]), "{scores:?}");
}

#[test]
fn exact_name_match_outranks_other_entries() {
    let tree = Tree::new();
    let hits = tree.complete(false, "local.h", 50);
    assert_eq!(names(&hits), ["local.h"]);
    assert!(hits[0].score > 900.0, "{}", hits[0].score);
}

#[test]
fn prefix_match_ignores_case() {
    let tree = Tree::new();
    assert_eq!(names(&tree.complete(true, "util", 50)), ["Util.hpp"]);
    assert_eq!(names(&tree.complete(true, "UTIL", 50)), ["Util.hpp"]);
    assert_eq!(names(&tree.complete(false, "STD", 50)), ["stdio.h"]);
}

#[test]
fn limit_truncates_the_sorted_list() {
    let tree = Tree::new();
    let hits = tree.complete(true, "", 2);
    assert_eq!(hits.len(), 2);
    assert!(hits.iter().all(|h| h.score >= 900.0), "{:?}", names(&hits));
}

#[test]
fn framework_dirs_complete_as_name_slash_header() {
    let tree = Tree::new();
    let hits = tree.complete(false, "", 100);
    let foo = find(&hits, "Foo/");
    assert_eq!(foo.item_kind, ItemKind::Mod);
    assert_eq!(source(foo), tree.root().join("fw/Foo.framework/Headers"));
    assert!(!names(&hits).contains(&"Bar.txt/"));
    let inside = tree.complete(false, "Foo/", 100);
    assert_eq!(names(&inside), ["Foo.h", "FooDefs.h"]);
    assert_eq!(inside[0].path, "Foo/Foo.h");
    assert_eq!(
        source(&inside[0]),
        tree.root().join("fw/Foo.framework/Headers/Foo.h")
    );
}

#[test]
fn missing_roots_and_files_are_ignored() {
    let tree = Tree::new();
    let search_dirs = vec![tree.root().join("nope")];
    let hits = complete(&IncludeRequest {
        quoted: true,
        typed: "",
        file: None,
        search_dirs: &search_dirs,
        system_dirs: &[],
        limit: 10,
    });
    assert!(hits.is_empty());
}
