mod fake_std;

use fake_std::{FakeStd, at};
use ride_engine::ItemKind;

const CELL: &str = "pub struct Cell;\nimpl Cell {\n    /// Makes a plain cell.\n    pub fn new() -> Cell { Cell }\n}\npub struct RefCell;\nimpl RefCell {\n    /// Makes a borrow-checked cell.\n    pub fn new() -> RefCell { RefCell }\n}\n";

const RESULT: &str = "/// The std result.\npub enum Result<T, E> {\n    Ok(T),\n    Err(E),\n}\n";

const STRING: &str = "/// A growable string.\npub struct String;\nimpl String {\n    pub fn new() -> String { String }\n}\n";

const JSON: &str = "pub enum Value {\n    Null,\n    String(super::string::String),\n}\n";

#[test]
fn two_constructors_in_one_file_keep_their_own_docs() {
    let std = FakeStd::with(&[("cell", CELL)]);
    let src =
        "use std::cell::{Cell, RefCell};\nfn f() {\n    Cell::new();\n    RefCell::new();\n}\n";
    let id = std.open(None, src);
    let cell = std.engine.quick_doc(id, at(src, "new", 0)).expect("cell");
    assert!(cell.html.contains("plain cell"), "{}", cell.html);
    let ref_cell = std
        .engine
        .quick_doc(id, at(src, "new", 1))
        .expect("refcell");
    assert!(
        ref_cell.html.contains("borrow-checked"),
        "{}",
        ref_cell.html
    );
}

#[test]
fn a_local_alias_wins_over_a_std_type_of_the_same_name() {
    let std = FakeStd::with(&[("result", RESULT)]);
    let src = "/// The local result.\ntype Result<T> = std::result::Result<T, ()>;\nfn f() -> Result<()> { todo!() }\n";
    let id = std.open(None, src);
    let usage = at(src, "Result<()>", 0);
    let hit = &std.engine.find_definitions(id, usage).hits[0];
    assert_eq!(hit.item_kind, ItemKind::Type);
    assert_eq!(hit.source_path, None);
    let doc = std.engine.quick_doc(id, usage).expect("doc");
    assert!(doc.html.contains("local result"), "{}", doc.html);
    let target = at(src, "Result<T, ()>", 0);
    let qualified = &std.engine.find_definitions(id, target).hits[0];
    assert_eq!(qualified.item_kind, ItemKind::Enum);
    assert!(qualified.source_path.is_some());
}

#[test]
fn a_path_qualifier_names_the_type_not_a_variant() {
    let std = FakeStd::with(&[("string", STRING), ("json", JSON)]);
    let src = "fn f() {\n    let s = String::new();\n}\n";
    let id = std.open(None, src);
    let resp = std.engine.find_definitions(id, at(src, "String", 0));
    let hit = resp.hits.first().expect("hit");
    assert_eq!(hit.item_kind, ItemKind::Struct, "{:?}", resp.hits);
    assert!(hit.path.ends_with("string::String"), "{}", hit.path);
}

#[test]
fn a_type_parameter_points_at_its_declaration() {
    let std = FakeStd::with(&[("result", RESULT)]);
    let src = "fn g<T: Clone>(x: T) -> T { x }\n";
    let id = std.open(None, src);
    let hit = &std.engine.find_definitions(id, at(src, "T", 2)).hits[0];
    assert_eq!(hit.byte_start, Some(src.find("T:").unwrap() as u32));
    assert_eq!(hit.signature, "T: Clone");
}

#[test]
fn rust_primitive_docs_stay_out_of_cpp() {
    let std = FakeStd::with(&[("result", RESULT)]);
    let src = "#include <array>\nbool ok(std::array<int, 2> a);\n";
    let id = std.open(Some("/tmp/ride-doc-lookup/main.cpp"), src);
    for needle in ["bool", "array<"] {
        let doc = std.engine.quick_doc(id, at(src, needle, 0));
        assert!(
            doc.as_ref()
                .is_none_or(|d| !d.origin_path.ends_with("primitive_docs.rs")),
            "{needle}: {:?}",
            doc.map(|d| d.origin_path)
        );
    }
}
