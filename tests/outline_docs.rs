use std::fs;

use ride_engine::{
    BufferSession, CompletionContext, CompletionHit, CompletionQuery, EngineConfig, ItemKind, Lang,
    OutlineItem, QueryMode, engine_start,
};

const RUST_SRC: &str = "/// A counter.\n///\n/// Counts things.\npub struct Counter {\n    n: u32,\n}\n\nimpl Counter {\n    /// Makes a counter.\n    pub fn new() -> Self {\n        Counter { n: 0 }\n    }\n}\n\nfn main() {\n    let n: u32 = 1;\n    let total = n;\n}\n";

const C_SRC: &str = "/// Number of sides of a shape.\n/// Always positive.\nint shape_sides(const struct shape *s);\n\n/**\n * @brief Area of the shape.\n *\n * Uses the sides.\n */\ndouble shape_area(const struct shape *s) { return 0; }\n\n#define MAX_SIDES 12\n#define SQUARE(x) ((x) * (x))\n\n// A polygon.\nstruct shape { int sides; double area; const char *label; };\nint main(void) {\n    struct shape s;\n    s.sides = 1;\n    const char *name = \"x\";\n    return name[0];\n}\n";

const CPP_SRC: &str = "class Circle {\npublic:\n    /// Area of the circle.\n    double area() const;\n    int count = 3;\n};\nvoid scale(const Circle &c, double k) { double f = c; }\n";

const SHAPES_H: &str = "#pragma once\nstruct shape { int sides; double area; };\ntypedef struct shape shape_t;\n/// Sides of a shape.\nint shape_sides(const shape_t *s);\n";
const MAIN_C: &str =
    "#include \"shapes.h\"\nint main(void) {\n    shape_t s;\n    return shape_sides(&s);\n}\n";

fn engine() -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn query(session_id: u64, prefix: &str, at: usize) -> CompletionQuery {
    CompletionQuery {
        query_id: 1,
        session_id,
        prefix: prefix.into(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at as u32,
        replace_start_byte: at as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    }
}

fn outline(lang: Lang, src: &str) -> Vec<OutlineItem> {
    let (_, open) = BufferSession::open_lang(lang, src.to_string(), None).unwrap();
    open.outline.unwrap()
}

fn item<'a>(outline: &'a [OutlineItem], name: &str, kind: ItemKind) -> &'a OutlineItem {
    outline
        .iter()
        .find(|o| o.name == name && o.kind == kind)
        .unwrap_or_else(|| panic!("{name} missing in {outline:?}"))
}

fn hits_after(
    engine: &ride_engine::Engine,
    ext: &str,
    src: &str,
    anchor: &str,
) -> Vec<CompletionHit> {
    let open = engine
        .open_session(
            ext.into(),
            Some(format!("/tmp/outline_docs.{ext}")),
            src.into(),
            None,
        )
        .unwrap();
    let at = src.find(anchor).expect("anchor") + anchor.len();
    engine
        .query_completions(query(open.session_id, "", at))
        .hits
}

fn hit<'a>(hits: &'a [CompletionHit], name: &str) -> &'a CompletionHit {
    hits.iter()
        .find(|h| h.name == name)
        .unwrap_or_else(|| panic!("{name} missing in {hits:?}"))
}

#[test]
fn rust_outline_carries_signature_and_doc() {
    let outline = outline(Lang::Rust, RUST_SRC);
    let new = item(&outline, "new", ItemKind::Method);
    assert_eq!(new.signature, "pub fn new() -> Self");
    assert_eq!(new.doc, "Makes a counter.");
    let counter = item(&outline, "Counter", ItemKind::Struct);
    assert_eq!(counter.signature, "pub struct Counter");
    assert_eq!(counter.doc, "A counter.");
}

#[test]
fn c_outline_carries_signature_and_comment_blocks() {
    let outline = outline(Lang::C, C_SRC);
    let sides = item(&outline, "shape_sides", ItemKind::Fn);
    assert_eq!(sides.signature, "int shape_sides(const struct shape *s)");
    assert_eq!(sides.doc, "Number of sides of a shape.\nAlways positive.");
    let area = item(&outline, "shape_area", ItemKind::Fn);
    assert_eq!(area.signature, "double shape_area(const struct shape *s)");
    assert_eq!(area.doc, "Area of the shape.\n\nUses the sides.");
    assert_eq!(
        item(&outline, "MAX_SIDES", ItemKind::Macro).signature,
        "#define MAX_SIDES"
    );
    assert_eq!(
        item(&outline, "SQUARE", ItemKind::Macro).signature,
        "#define SQUARE(x)"
    );
    let shape = item(&outline, "shape", ItemKind::Struct);
    assert_eq!(shape.signature, "struct shape");
    assert_eq!(shape.doc, "A polygon.");
    assert_eq!(item(&outline, "main", ItemKind::Fn).doc, "");
}

#[test]
fn cpp_method_inside_a_class_carries_signature_and_doc() {
    let outline = outline(Lang::Cpp, CPP_SRC);
    let area = item(&outline, "area", ItemKind::Method);
    assert_eq!(area.signature, "double area() const");
    assert_eq!(area.doc, "Area of the circle.");
    assert_eq!(
        item(&outline, "Circle", ItemKind::Class).signature,
        "class Circle"
    );
}

#[test]
fn declared_locals_carry_their_annotated_type_as_detail() {
    let engine = engine();
    let rust = hits_after(&engine, "rs", RUST_SRC, "let total = n");
    assert_eq!(hit(&rust, "n").detail, "u32");
    assert_eq!(hit(&rust, "new").signature, "pub fn new() -> Self");
    assert_eq!(hit(&rust, "new").doc_first_sentence, "Makes a counter");
    let c = hits_after(&engine, "c", C_SRC, "return name");
    assert_eq!(hit(&c, "name").detail, "const char *");
    let cpp = hits_after(&engine, "cpp", CPP_SRC, "double f = c");
    assert_eq!(hit(&cpp, "c").detail, "const Circle &");
}

#[test]
fn struct_field_members_carry_their_type_as_detail() {
    let engine = engine();
    let hits = hits_after(&engine, "c", C_SRC, "struct shape s;\n    s.");
    assert_eq!(hit(&hits, "sides").detail, "int");
    assert_eq!(hit(&hits, "area").detail, "double");
    assert_eq!(hit(&hits, "label").detail, "const char *");
    assert_eq!(hit(&hits, "sides").signature, "int sides");
}

#[test]
fn header_items_carry_signature_doc_and_file_name() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    fs::write(root.join("shapes.h"), SHAPES_H).unwrap();
    fs::write(root.join("main.c"), MAIN_C).unwrap();
    let engine = engine();
    let open = engine
        .open_session(
            "c".into(),
            Some(root.join("main.c").display().to_string()),
            MAIN_C.into(),
            None,
        )
        .unwrap();
    let at = MAIN_C.find("shape_sides(&s)").unwrap() + "shape_".len();
    let resp = engine.query_completions(query(open.session_id, "shape_", at));
    let sides = hit(&resp.hits, "shape_sides");
    assert_eq!(sides.signature, "int shape_sides(const shape_t *s)");
    assert_eq!(sides.doc_first_sentence, "Sides of a shape");
    assert_eq!(sides.doc_paragraph, "Sides of a shape.");
    assert_eq!(sides.detail, "shapes.h");
    assert!(sides.source_path.as_deref().unwrap().ends_with("shapes.h"));
    let at = MAIN_C.find("shape_sides(&s)").unwrap() + 2;
    let def = engine.find_definitions(open.session_id, at as u32);
    assert_eq!(def.hits[0].signature, "int shape_sides(const shape_t *s)");
    assert_eq!(def.hits[0].detail, "shapes.h");
}
