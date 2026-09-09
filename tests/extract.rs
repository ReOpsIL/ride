use std::path::{Path, PathBuf};

use ride_engine::{
    CrateContext, EngineConfig, ItemDoc, ItemKind, Scope, Visibility, cargo_home, extract_crate,
    extract_source,
};

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn sample_ctx() -> CrateContext {
    CrateContext {
        crate_name: "sample".into(),
        crate_version: "0.1.0".into(),
        crate_root: PathBuf::from("<mem>"),
        edition: Some("2021".into()),
        features: Vec::new(),
        scope: Scope::Workspace,
    }
}

fn paths(items: &[ItemDoc]) -> Vec<&str> {
    items.iter().map(|i| i.path.as_str()).collect()
}

fn item<'a>(items: &'a [ItemDoc], path: &str) -> &'a ItemDoc {
    items
        .iter()
        .find(|i| i.path == path)
        .unwrap_or_else(|| panic!("missing {path} in {:?}", paths(items)))
}

#[test]
fn set_language_smoke() {
    let mut parser = tree_sitter::Parser::new();
    parser
        .set_language(&tree_sitter_rust::LANGUAGE.into())
        .expect("tree-sitter-rust language");
    let tree = parser.parse("pub fn f() {}", None).expect("parse");
    assert_eq!(tree.root_node().kind(), "source_file");
}

#[test]
fn extracts_named_items_and_impl_methods() {
    let src = r#"
        /// A visible struct.
        pub struct Foo;
        impl Foo {
            pub fn new() {}
            fn hidden() {}
        }
        pub trait Trait { fn required(&self); }
        impl Trait for Foo { fn required(&self) {} }
        pub fn free_fn() {}
    "#;
    let items = extract_source(src, &sample_ctx(), &["sample".into()]).unwrap();
    assert_eq!(item(&items, "sample::Foo").item_kind, ItemKind::Struct);
    assert_eq!(item(&items, "sample::Foo").visibility, Visibility::Pub);
    assert_eq!(item(&items, "Foo::new").item_kind, ItemKind::Method);
    assert_eq!(item(&items, "Foo::hidden").visibility, Visibility::Private);
    assert_eq!(item(&items, "sample::Trait").item_kind, ItemKind::Trait);
    assert_eq!(item(&items, "Trait::required").item_kind, ItemKind::Method);
    assert_eq!(item(&items, "Foo::required").item_kind, ItemKind::Method);
    assert_eq!(item(&items, "sample::free_fn").item_kind, ItemKind::Fn);
    assert!(
        item(&items, "sample::Foo")
            .doc_first_paragraph
            .contains("visible struct")
    );
}

#[test]
fn extracts_function_signature_item() {
    let src = "pub trait T { fn sig(&self) -> u32; }";
    let items = extract_source(src, &sample_ctx(), &["sample".into()]).unwrap();
    let sig = item(&items, "T::sig");
    assert_eq!(sig.item_kind, ItemKind::Method);
    assert!(sig.signature.contains("fn sig"));
}

#[test]
fn unicode_byte_range() {
    let src = "pub fn café() { let _ = \"🦀\"; }\n";
    let items = extract_source(src, &sample_ctx(), &["sample".into()]).unwrap();
    let f = item(&items, "sample::café");
    let (start, end) = f.byte_range;
    let slice = &src[start as usize..end as usize];
    assert!(slice.contains("café"));
}

#[test]
fn sample_crate_module_graph() {
    let root = fixtures().join("sample_crate");
    let items = extract_crate(&root, Scope::Workspace).unwrap();
    item(&items, "sample");
    item(&items, "sample::Foo");
    item(&items, "Foo::new");
    item(&items, "sample::time::sleep");
    item(&items, "sample::time::instant::Instant");
    item(&items, "sample::private_mod::only_in_private");
    item(&items, "sample::renamed::via_path");
    item(&items, "sample::my_macro");
    item(&items, "sample::K");
    item(&items, "sample::Alias");
    item(&items, "sample::S");
    item(&items, "sample::E");
    item(&items, "sample::U");
    assert_eq!(item(&items, "sample::my_macro").visibility, Visibility::Pub);
    assert_eq!(
        item(&items, "sample::private_mod").visibility,
        Visibility::Private
    );
}

fn find_unpacked(name: &str) -> Option<PathBuf> {
    let home = cargo_home(&EngineConfig {
        index_dir: ".".into(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    let src = home.join("registry/src");
    let prefix = format!("{name}-");
    let mut found = None;
    let Ok(sources) = std::fs::read_dir(&src) else {
        return None;
    };
    for source in sources.flatten() {
        let Ok(crates) = std::fs::read_dir(source.path()) else {
            continue;
        };
        for entry in crates.flatten() {
            let fname = entry.file_name();
            let fname = fname.to_string_lossy();
            if fname.starts_with(&prefix) {
                let rest = &fname[prefix.len()..];
                if rest.starts_with(|c: char| c.is_ascii_digit())
                    && entry.path().join("Cargo.toml").is_file()
                {
                    found = Some(entry.path());
                }
            }
        }
    }
    found
}

fn snapshot_count(name: &str, version: &str, count: usize) {
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/extract/snapshots");
    let path = dir.join(format!("{name}.count"));
    let line = format!("{version} {count}\n");
    if std::env::var("UPDATE_EXTRACT_SNAPSHOTS").is_ok() {
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(&path, line).unwrap();
        return;
    }
    let Ok(text) = std::fs::read_to_string(&path) else {
        return;
    };
    let Some((snap_ver, snap_count)) = text.trim().split_once(' ') else {
        return;
    };
    if snap_ver == version {
        let expected: usize = snap_count.parse().unwrap();
        assert_eq!(count, expected, "{name} {version} item count");
    }
}

fn crate_version(root: &Path) -> String {
    root.file_name()
        .and_then(|n| n.to_str())
        .and_then(|n| n.rsplit_once('-').map(|(_, v)| v.to_string()))
        .unwrap_or_else(|| "unknown".into())
}

#[test]
fn serde_snapshot() {
    let Some(root) = find_unpacked("serde") else {
        return;
    };
    let items = extract_crate(&root, Scope::Cache).unwrap();
    assert!(items.iter().any(|i| i.path.ends_with("Serialize")));
    assert!(items.iter().any(|i| i.path.ends_with("Deserialize")));
    snapshot_count("serde", &crate_version(&root), items.len());
    let Some(core) = find_unpacked("serde_core") else {
        return;
    };
    let core_items = extract_crate(&core, Scope::Cache).unwrap();
    assert!(
        core_items.len() >= 40,
        "serde_core items {}",
        core_items.len()
    );
    assert!(core_items.iter().any(|i| i.path.ends_with("Serialize")));
    snapshot_count("serde_core", &crate_version(&core), core_items.len());
}

#[test]
fn tokio_snapshot() {
    let Some(root) = find_unpacked("tokio") else {
        return;
    };
    let items = extract_crate(&root, Scope::Cache).unwrap();
    assert!(items.len() >= 80, "tokio items {}", items.len());
    assert!(
        items
            .iter()
            .any(|i| i.path == "tokio::spawn" || i.name == "spawn")
    );
    snapshot_count("tokio", &crate_version(&root), items.len());
}

#[test]
fn std_collections_snapshot() {
    let sys = std::process::Command::new("rustc")
        .args(["--print", "sysroot"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| PathBuf::from(s.trim()));
    let Some(sys) = sys else {
        return;
    };
    let std_root = sys.join("lib/rustlib/src/rust/library/std");
    if !std_root.join("Cargo.toml").is_file() {
        return;
    }
    let items = extract_crate(&std_root, Scope::Sysroot).unwrap();
    assert!(
        items.iter().any(|i| i.path == "std::collections::HashMap"),
        "missing HashMap in {:?}",
        paths(&items)
            .into_iter()
            .filter(|p| p.contains("HashMap"))
            .collect::<Vec<_>>()
    );
    let collections: Vec<_> = items
        .iter()
        .filter(|i| i.path.starts_with("std::collections"))
        .collect();
    assert!(collections.len() >= 10);
    snapshot_count("std_collections", "sysroot", collections.len());
}

#[test]
fn pub_use_rewrites_path() {
    let src = r#"
        pub mod hash_map {
            pub struct HashMap;
        }
        pub use hash_map::HashMap;
    "#;
    let items = extract_source(src, &sample_ctx(), &["std".into()]).unwrap();
    assert_eq!(
        item(&items, "std::hash_map::HashMap").item_kind,
        ItemKind::Struct
    );
    assert!(
        items.iter().any(|i| i.path == "std::HashMap"),
        "{:?}",
        paths(&items)
    );
}

#[test]
fn skips_huge_file() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    std::fs::write(
        root.join("Cargo.toml"),
        "[package]\nname = \"huge\"\nversion = \"0.1.0\"\nedition = \"2021\"\n",
    )
    .unwrap();
    std::fs::create_dir_all(root.join("src")).unwrap();
    let big = "pub fn x() {}\n".repeat(40_000);
    assert!(big.len() as u64 > 512 * 1024);
    std::fs::write(root.join("src/lib.rs"), big).unwrap();
    let items = extract_crate(root, Scope::Workspace).unwrap();
    assert!(!items.iter().any(|i| i.name == "x"));
}

#[test]
fn does_not_follow_mod_outside_crate() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path().join("crate");
    std::fs::create_dir_all(root.join("src")).unwrap();
    std::fs::write(
        root.join("Cargo.toml"),
        "[package]\nname = \"esc\"\nversion = \"0.1.0\"\nedition = \"2021\"\n",
    )
    .unwrap();
    std::fs::write(
        root.join("src/lib.rs"),
        "#[path = \"../../outside.rs\"]\nmod outside;\n",
    )
    .unwrap();
    std::fs::write(dir.path().join("outside.rs"), "pub fn leaked() {}\n").unwrap();
    let items = extract_crate(&root, Scope::Workspace).unwrap();
    assert!(!items.iter().any(|i| i.name == "leaked"));
}

#[test]
fn signature_drops_attributes_and_tidies_generics() {
    let src = "pub struct HashMap<\n    K,\n    V,\n    S = RandomState,\n    #[unstable(feature = \"allocator_api\", issue = \"32838\")] A: Allocator = Global,\n> {\n    base: u8,\n}\n#[inline]\npub fn f<#[cfg(x)] T>(t: T) -> T { t }\n";
    let ctx = ride_engine::CrateContext {
        crate_name: "c".into(),
        crate_version: "0.0.0".into(),
        crate_root: std::path::PathBuf::from("<mem>"),
        edition: None,
        features: Vec::new(),
        scope: ride_engine::Scope::Workspace,
    };
    let items = ride_engine::extract_source(src, &ctx, &["c".into()]).unwrap();
    let map = items.iter().find(|i| i.name == "HashMap").unwrap();
    assert_eq!(
        map.signature,
        "pub struct HashMap<K, V, S = RandomState, A: Allocator = Global>"
    );
    let f = items.iter().find(|i| i.name == "f").unwrap();
    assert_eq!(f.signature, "pub fn f<T>(t: T) -> T");
}
