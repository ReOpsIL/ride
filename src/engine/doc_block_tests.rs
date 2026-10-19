use super::lift_named;
use crate::highlight::Lang;

#[test]
fn a_type_keeps_its_docs_when_the_byte_lands_on_another_item() {
    let src = "/// Old notes.\nfn path() {}\n\n/// A slice of a path.\n///\n/// Open a path.\npub struct Path;\n";
    let at = src.find("fn path").expect("fn");
    let lifted = lift_named(Lang::Rust, src, at, "Path").expect("type");
    assert!(
        lifted.markdown.contains("A slice of a path"),
        "{}",
        lifted.markdown
    );
    assert!(
        lifted.markdown.contains("Open a path"),
        "{}",
        lifted.markdown
    );
    assert!(
        !lifted.markdown.contains("Old notes"),
        "{}",
        lifted.markdown
    );
}

#[test]
fn a_plain_note_between_the_docs_and_the_type_keeps_the_docs() {
    let src = "/// A slice of a path.\n///\n/// Open a path.\n#[stable]\n// layout note\n#[repr(transparent)]\npub struct Path;\n";
    let at = src.find("struct Path").expect("struct");
    let lifted = lift_named(Lang::Rust, src, at, "Path").expect("type");
    assert!(
        lifted.markdown.contains("A slice of a path"),
        "{}",
        lifted.markdown
    );
    assert!(
        lifted.markdown.contains("Open a path"),
        "{}",
        lifted.markdown
    );
    assert!(
        !lifted.markdown.contains("layout note"),
        "{}",
        lifted.markdown
    );
}

#[test]
fn a_blank_line_before_the_attributes_keeps_the_type_docs() {
    let src = "/// A hash map implemented with quadratic probing.\n///\n/// The default hashing algorithm is SipHash.\n\n#[stable]\n#[rustc_insignificant_dtor]\npub struct HashMap<K, V> {\n    base: u8,\n}\n";
    let at = src.find("struct HashMap").expect("struct");
    let lifted = lift_named(Lang::Rust, src, at, "HashMap").expect("type");
    assert!(
        lifted.markdown.contains("quadratic probing"),
        "{}",
        lifted.markdown
    );
    assert!(lifted.markdown.contains("SipHash"), "{}", lifted.markdown);
}

#[test]
fn the_toolchain_hashmap_keeps_its_docs() {
    let Ok(Some(root)) = crate::discover::rustc_sysroot() else {
        return;
    };
    let path = root.join("lib/rustlib/src/rust/library/std/src/collections/hash/map.rs");
    let Ok(src) = std::fs::read_to_string(&path) else {
        return;
    };
    let at = src.find("pub struct HashMap<").expect("struct");
    let lifted = lift_named(Lang::Rust, &src, at, "HashMap").expect("type");
    assert!(
        lifted.markdown.contains("quadratic probing"),
        "{}",
        lifted.markdown
    );
    assert!(lifted.markdown.contains("SipHash"), "{}", lifted.markdown);
}
