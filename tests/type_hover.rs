use std::sync::Arc;

use ride_engine::{BufferSession, Engine, EngineConfig, Lang, engine_start};

fn engine() -> (tempfile::TempDir, Arc<Engine>) {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: dir.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    });
    (dir, engine)
}

fn open(engine: &Engine, src: &str) -> u64 {
    engine
        .open_session("buf".into(), None, src.into(), None)
        .unwrap()
        .session_id
}

fn has_primitive_docs() -> bool {
    let Ok(Some(root)) = ride_engine::rustc_sysroot() else {
        return false;
    };
    root.join("lib/rustlib/src/rust/library/core/src/primitive_docs.rs")
        .is_file()
}

#[test]
fn a_type_after_a_comma_keeps_the_local_struct() {
    let (_dir, engine) = engine();
    let src = "pub const E: f64 = 1.0;\nstruct E;\nfn f(v: Result<(), E>) {}\n";
    let id = open(&engine, src);
    let at = (src.find(", E>").unwrap() + 2) as u32;
    let doc = engine.quick_doc(id, at).expect("doc");
    assert!(doc.signature.contains("struct E"), "{}", doc.signature);
    assert!(!doc.signature.contains("f64"), "{}", doc.signature);
}

#[test]
fn a_type_and_a_value_with_the_same_name_stay_apart() {
    let (_dir, engine) = engine();
    let src = "fn Box() {}\nstruct Box;\nfn f(x: Box) { let _y = Box; }\n";
    let id = open(&engine, src);
    let type_at = (src.find("x: Box").unwrap() + "x: ".len()) as u32;
    let value_at = (src.find("= Box").unwrap() + "= ".len()) as u32;
    let type_doc = engine.quick_doc(id, type_at).expect("type");
    let value_doc = engine.quick_doc(id, value_at).expect("value");
    assert!(
        type_doc.signature.contains("struct Box"),
        "{}",
        type_doc.signature
    );
    assert!(
        value_doc.signature.contains("fn Box"),
        "{}",
        value_doc.signature
    );
}

#[test]
fn self_in_an_impl_uses_the_enclosing_type() {
    let (_dir, engine) = engine();
    let src = "struct LineOffsets;\nimpl LineOffsets {\n    fn new() -> Self { todo!() }\n}\n";
    let id = open(&engine, src);
    let at = src.find("Self").unwrap() as u32;
    let doc = engine.quick_doc(id, at).expect("doc");
    assert!(doc.signature.contains("LineOffsets"), "{}", doc.signature);
    assert!(!doc.signature.contains("SELF"), "{}", doc.signature);
}

#[test]
fn a_type_parameter_keeps_its_bound() {
    let (_dir, engine) = engine();
    let src = "pub const E: f64 = 1.0;\nfn g<E: Read>(value: E) {}\n";
    let id = open(&engine, src);
    let at = (src.find("value: E").unwrap() + "value: ".len()) as u32;
    let doc = engine.quick_doc(id, at).expect("doc");
    assert!(doc.signature.contains("E: Read"), "{}", doc.signature);
    assert!(!doc.signature.contains("f64"), "{}", doc.signature);
}

#[test]
fn a_where_bound_joins_the_type_parameter() {
    let (_dir, engine) = engine();
    let src = "fn g<T>(x: T) where T: Send {}\n";
    let id = open(&engine, src);
    let at = (src.find("(x: T)").unwrap() + "(x: ".len()) as u32;
    let doc = engine.quick_doc(id, at).expect("doc");
    assert!(doc.signature.contains("Send"), "{}", doc.signature);
}

#[test]
fn a_plain_note_does_not_drop_the_type_docs() {
    let (_dir, engine) = engine();
    let src = "/// A slice of a path.\n///\n/// Open a path.\n#[stable]\n// layout note\n#[repr(transparent)]\npub struct Path;\nfn f(p: &Path) {}\n";
    let id = open(&engine, src);
    let at = src.rfind("Path").unwrap() as u32;
    let doc = engine.quick_doc(id, at).expect("doc");
    assert!(doc.html.contains("A slice of a path"), "{}", doc.html);
    assert!(doc.html.contains("Open a path"), "{}", doc.html);
    assert!(!doc.html.contains("layout note"), "{}", doc.html);
}

#[test]
fn a_primitive_shows_its_toolchain_docs() {
    if !has_primitive_docs() {
        return;
    }
    let (_dir, engine) = engine();
    let src = "fn f(x: i32) {}\n";
    let id = open(&engine, src);
    let at = src.find("i32").unwrap() as u32;
    let doc = engine.quick_doc(id, at).expect("doc");
    assert!(doc.html.contains("32-bit"), "{}", doc.html);
    assert_eq!(doc.signature, "i32");
}

#[test]
fn a_lifetime_is_not_a_symbol() {
    let src = "fn f(x: &'static str) {}\n";
    let (session, _) = BufferSession::open_lang(Lang::Rust, src.to_string(), None).unwrap();
    let static_at = src.find("static").unwrap() as u32;
    assert!(session.symbol_at(static_at).is_none());
    let str_at = src.find("str").unwrap() as u32;
    assert_eq!(session.symbol_at(str_at).unwrap().name, "str");
}
