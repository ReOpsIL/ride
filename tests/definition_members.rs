use std::fs;

use ride_engine::{DefinitionExcerpt, EngineConfig, engine_start};

fn config(index_dir: &std::path::Path) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    }
}

fn excerpts(src: &str, path: &str, needle: &str) -> Vec<DefinitionExcerpt> {
    let at = src.find(needle).expect(needle) + 1;
    excerpts_at(src, path, at)
}

fn excerpts_at(src: &str, path: &str, at: usize) -> Vec<DefinitionExcerpt> {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(config(dir.path()));
    let open = engine
        .open_session("buf".into(), Some(path.into()), src.into(), None)
        .unwrap();
    engine.quick_definition(open.session_id, at as u32)
}

fn texts(got: &[DefinitionExcerpt]) -> Vec<&str> {
    got.iter().map(|e| e.text.as_str()).collect()
}

const RUST: &str = "enum Color {\n    Red,\n    Green(u8),\n    Blue { v: u8 },\n}\nenum Light { Red, Off }\nimpl Color {\n    fn new() -> Self { Self::Green(0) }\n}\nstruct Other;\nimpl Other {\n    fn new() -> Self { Other }\n}\nfn main() {\n    let c = Color::Green(1);\n    let d = Color::Blue { v: 2 };\n    match c { Color::Red => {}, _ => {} }\n    let n = Color::new();\n}\nfn globbed() {\n    use Light::*;\n    let o = Off;\n}\n";

#[test]
fn rust_qualified_variants() {
    assert_eq!(
        texts(&excerpts(RUST, "/tmp/t.rs", "Green(1)")),
        ["Green(u8)"]
    );
    assert_eq!(
        texts(&excerpts(RUST, "/tmp/t.rs", "Blue { v: 2")),
        ["Blue { v: u8 }"]
    );
    let red = excerpts(RUST, "/tmp/t.rs", "Red =>");
    assert_eq!(red.len(), 1, "{red:?}");
    assert_eq!(red[0].line, 2);
}

#[test]
fn rust_self_qualified_variant() {
    let got = excerpts(RUST, "/tmp/t.rs", "Green(0)");
    assert_eq!(texts(&got), ["Green(u8)"]);
}

#[test]
fn rust_unqualified_variant() {
    let got = excerpts(RUST, "/tmp/t.rs", "Off;");
    assert_eq!(texts(&got), ["Off"]);
}

#[test]
fn rust_listed_variant_import() {
    let src =
        "enum Light { Red, Off }\nuse Light::{Red};\nfn main() { let r = Red; let o = Off; }\n";
    assert_eq!(texts(&excerpts(src, "/tmp/t.rs", "Red; let")), ["Red"]);
    assert!(excerpts(src, "/tmp/t.rs", "Off; }").is_empty());
}

#[test]
fn rust_variant_does_not_shadow_a_type_of_the_same_name() {
    let src =
        "struct Circle;\nenum Shape { Circle(Circle) }\nfn main() { let c: Circle = Circle; }\n";
    let got = excerpts(src, "/tmp/t.rs", "Circle = ");
    assert_eq!(texts(&got), ["struct Circle;"], "{got:?}");
}

#[test]
fn rust_variant_declaration_resolves_to_itself() {
    let got = excerpts(RUST, "/tmp/t.rs", "Green(u8)");
    assert_eq!(texts(&got), ["Green(u8)"]);
}

const CPP: &str = "enum class Shape { Circle, Square };\nenum Plain { A, B };\nint main() { Shape s = Shape::Circle; int x = B; int y = Plain::A; int Square = 0; return Square; }\n";

#[test]
fn cpp_scoped_and_plain_enumerators() {
    assert_eq!(texts(&excerpts(CPP, "/tmp/t.cpp", "Circle;")), ["Circle"]);
    assert_eq!(texts(&excerpts(CPP, "/tmp/t.cpp", "B; int")), ["B"]);
    assert_eq!(texts(&excerpts(CPP, "/tmp/t.cpp", "A; int")), ["A"]);
}

#[test]
fn cpp_enum_class_members_need_a_qualifier() {
    assert!(excerpts(CPP, "/tmp/t.cpp", "Square; }").is_empty());
}

#[test]
fn c_typedef_and_anonymous_enumerators() {
    let src = "typedef enum { RED, GREEN } color;\nenum { MAX_ITEMS = 8 };\nint main(void) { color c = GREEN; return MAX_ITEMS; }\n";
    assert_eq!(texts(&excerpts(src, "/tmp/t.c", "GREEN;")), ["GREEN"]);
    assert_eq!(
        texts(&excerpts(src, "/tmp/t.c", "MAX_ITEMS;")),
        ["MAX_ITEMS = 8"]
    );
}

#[test]
fn cpp_qualified_method_keeps_out_of_line_body() {
    let src = "struct Circle { double area() const; };\ndouble Circle::area() const { return 3.0; }\nint main() { Circle c; return (int)c.Circle::area(); }\n";
    let got = excerpts(src, "/tmp/t.cpp", "area(); }");
    assert!(
        texts(&got).iter().any(|t| t.contains("return 3.0")),
        "{got:?}"
    );
}

#[test]
fn cpp_enumerator_from_header() {
    let dir = tempfile::tempdir().unwrap();
    let header = dir.path().join("shape.hpp");
    fs::write(&header, "enum class Shape { Circle, Square };\n").unwrap();
    let source = dir.path().join("main.cpp");
    let src = "#include \"shape.hpp\"\nint main() { Shape s = Shape::Square; return 0; }\n";
    fs::write(&source, src).unwrap();
    let got = excerpts(src, &source.display().to_string(), "Square;");
    assert_eq!(texts(&got), ["Square"], "{got:?}");
    assert!(got[0].path.ends_with("shape.hpp"), "{}", got[0].path);
}

#[test]
fn rust_trait_qualified_call_keeps_impls() {
    let src = "trait Znarf { fn znarf(&self); }\nstruct ZA;\nstruct ZB;\nimpl Znarf for ZA { fn znarf(&self) {} }\nimpl Znarf for ZB { fn znarf(&self) {} }\nfn main() { Znarf::znarf(&ZA); }\n";
    let got = excerpts(src, "/tmp/t.rs", "znarf(&ZA)");
    let labels: Vec<&str> = got.iter().map(|e| e.label.as_str()).collect();
    assert_eq!(labels, ["trait", "impl for ZA", "impl for ZB"], "{got:?}");
}

#[test]
fn cpp_enumerators_in_namespace_and_class_scope() {
    let src = "namespace ns { enum E { A, B }; int in_ns() { return A; } }\nstruct S { enum Mode { Box, Line }; int m() { return Box; } };\nint main() { int x = ns::B; int y = S::Line; return x + y; }\n";
    assert_eq!(texts(&excerpts(src, "/tmp/t.cpp", "B; int y")), ["B"]);
    assert_eq!(
        texts(&excerpts(src, "/tmp/t.cpp", "Line; return")),
        ["Line"]
    );
    assert_eq!(texts(&excerpts(src, "/tmp/t.cpp", "A; } }")), ["A"]);
    assert_eq!(texts(&excerpts(src, "/tmp/t.cpp", "Box; } };")), ["Box"]);
}

#[test]
fn cpp_scoped_enumerators_are_not_visible_outside() {
    let src = "namespace ns { enum E { A }; }\nstruct S { enum Mode { Box }; };\nint main() { int A = 0; int Box = 1; return A + Box; }\n";
    assert!(excerpts(src, "/tmp/t.cpp", "A + Box").is_empty());
    assert!(excerpts(src, "/tmp/t.cpp", "Box; }").is_empty());
}

#[test]
fn c_function_local_enum_stays_local() {
    let src = "int f(void) { enum { LOCAL_K = 3 }; return LOCAL_K; }\nint g(void) { int LOCAL_K = 1; return LOCAL_K; }\n";
    assert_eq!(
        texts(&excerpts(src, "/tmp/t.c", "LOCAL_K; }\nint")),
        ["LOCAL_K = 3"]
    );
    let got = excerpts(src, "/tmp/t.c", "LOCAL_K; }\n");
    assert_eq!(got.len(), 1, "{got:?}");
    let tail = src.rfind("LOCAL_K;").unwrap() + 1;
    let outside = excerpts_at(src, "/tmp/t.c", tail);
    assert!(
        outside.iter().all(|e| !e.text.contains("= 3")),
        "{outside:?}"
    );
}

#[test]
fn rust_use_inside_function_stays_local() {
    let src =
        "enum Light { Red, Off }\nfn a() { use Light::*; let r = Red; }\nfn b() { let r = Red; }\n";
    assert_eq!(texts(&excerpts(src, "/tmp/t.rs", "Red; }\nfn b")), ["Red"]);
    let tail = src.rfind("Red; }").unwrap() + 1;
    assert!(excerpts_at(src, "/tmp/t.rs", tail).is_empty());
}

#[test]
fn rust_use_alias_resolves_to_variant() {
    let src = "enum Light { Red, Off }\nuse Light::Red as Stop;\nfn main() { let s = Stop; }\n";
    assert_eq!(texts(&excerpts(src, "/tmp/t.rs", "Stop; }")), ["Red"]);
}

#[test]
fn rust_qualified_method_prefers_the_qualifier_type() {
    let src = "struct Color;\nimpl Color {\n    fn new() -> Self { Color }\n}\nstruct Other;\nimpl Other {\n    fn new() -> Self { Other }\n}\nfn main() {\n    let o = Other::new();\n    let c = Color::new();\n}\n";
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(config(dir.path()));
    let open = engine
        .open_session("buf".into(), Some("/tmp/t.rs".into()), src.into(), None)
        .unwrap();
    let other_def = src.find("fn new() -> Self { Other }").unwrap() as u32;
    let color_def = src.find("fn new() -> Self { Color }").unwrap() as u32;
    let first = |needle: &str| {
        let at = src.find(needle).unwrap() as u32 + needle.find("new").unwrap() as u32 + 1;
        let hits = engine.find_definitions(open.session_id, at).hits;
        assert_eq!(hits.len(), 2, "{hits:?}");
        hits[0].byte_start.unwrap()
    };
    assert_eq!(first("Other::new()"), other_def);
    assert_eq!(first("Color::new()"), color_def);
    let got = excerpts(src, "/tmp/t.rs", "new();\n    let c");
    assert_eq!(got[0].label, "impl for Other", "{got:?}");
}
