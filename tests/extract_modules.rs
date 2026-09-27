use std::fs;
use std::path::Path;

use ride_engine::{ItemDoc, Scope, extract_crate};

fn write(root: &Path, rel: &str, text: &str) {
    let path = root.join(rel);
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, text).unwrap();
}

fn manifest(root: &Path, name: &str) {
    write(
        root,
        "Cargo.toml",
        &format!("[package]\nname = \"{name}\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"),
    );
}

fn find<'a>(items: &'a [ItemDoc], path: &str) -> Option<&'a ItemDoc> {
    items.iter().find(|i| i.path == path)
}

#[test]
fn inline_module_children_resolve_under_the_inline_dir() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    manifest(root, "modfix");
    write(root, "src/lib.rs", "pub mod a {\n    pub mod b;\n}\n");
    write(root, "src/a/b.rs", "pub fn deep() {}\n");
    write(root, "src/b.rs", "pub fn decoy() {}\n");
    let items = extract_crate(root, Scope::Workspace).unwrap();
    let deep = find(&items, "modfix::a::b::deep").expect("deep");
    assert!(deep.reachable);
    assert!(find(&items, "modfix::a::b::decoy").is_none());
}

#[test]
fn bin_entry_children_resolve_beside_the_entry() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    write(
        root,
        "Cargo.toml",
        "[package]\nname = \"binfix\"\nversion = \"0.1.0\"\n\n[[bin]]\nname = \"tool\"\npath = \"tools/tool.rs\"\n",
    );
    write(root, "tools/tool.rs", "pub mod helper;\nfn main() {}\n");
    write(root, "tools/helper.rs", "pub fn help() {}\n");
    let items = extract_crate(root, Scope::Workspace).unwrap();
    let help = find(&items, "binfix::helper::help").expect("help");
    assert!(help.reachable);
}

#[test]
fn non_mod_rs_file_children_live_in_the_stem_dir() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    manifest(root, "stemfix");
    write(root, "src/lib.rs", "pub mod outer;\n");
    write(
        root,
        "src/outer.rs",
        "pub mod inner {\n    pub mod leaf;\n}\n",
    );
    write(root, "src/outer/inner/leaf.rs", "pub fn tip() {}\n");
    let items = extract_crate(root, Scope::Workspace).unwrap();
    assert!(find(&items, "stemfix::outer::inner::leaf::tip").is_some_and(|i| i.reachable));
}

#[test]
fn symlink_loops_do_not_explode_the_walk() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    manifest(root, "loopfix");
    write(root, "src/lib.rs", "pub fn top() {}\n");
    write(root, "src/extra/stray.rs", "pub fn stray() {}\n");
    std::os::unix::fs::symlink(root.join("src"), root.join("src/extra/l1")).unwrap();
    std::os::unix::fs::symlink(root.join("src"), root.join("src/extra/l2")).unwrap();
    let items = extract_crate(root, Scope::Workspace).unwrap();
    assert!(find(&items, "loopfix::top").is_some());
    assert!(find(&items, "loopfix::extra::stray::stray").is_some());
}

#[test]
fn unreached_parent_modules_are_walked_before_their_children() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    manifest(root, "orderfix");
    write(root, "src/lib.rs", "wrap! { pub mod outer; }\n");
    write(
        root,
        "src/outer/mod.rs",
        "#[path = \"impls/real.rs\"]\npub mod imp;\n#[cfg(test)]\nmod tests;\n",
    );
    write(root, "src/outer/impls/real.rs", "pub fn real() {}\n");
    write(root, "src/outer/tests.rs", "pub fn only_test() {}\n");
    let items = extract_crate(root, Scope::Workspace).unwrap();
    assert!(find(&items, "orderfix::outer::imp::real").is_some());
    assert!(!items.iter().any(|i| i.name == "only_test"));
}
