use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, TestFramework, TestMarker, engine_start};

fn engine() -> Arc<Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn markers(path: &str, text: &str) -> Vec<TestMarker> {
    let engine = engine();
    let open = engine
        .open_session(
            "b".to_string(),
            Some(path.to_string()),
            text.to_string(),
            None,
        )
        .unwrap();
    engine.test_markers(open.session_id, Some(path.to_string()))
}

#[test]
fn rust_test_functions_are_module_qualified() {
    let text = "pub fn add(a: i32) -> i32 {\n    a\n}\n\n#[cfg(test)]\nmod tests {\n    #[test]\n    fn adds() {\n        assert_eq!(1, 1);\n    }\n}\n";
    let found = markers("/p/src/util.rs", text);
    assert_eq!(found.len(), 1);
    assert_eq!(found[0].name, "util::tests::adds");
    assert_eq!(found[0].framework, Some(TestFramework::Cargo));
    assert_eq!(
        text[found[0].byte_start as usize..].lines().next(),
        Some("    fn adds() {")
    );
}

#[test]
fn rust_file_scope_test_and_main() {
    let text =
        "fn main() {\n    println!(\"hi\");\n}\n\n#[test]\nfn counts() {\n    assert!(true);\n}\n";
    let found = markers("/p/src/main.rs", text);
    assert_eq!(found.len(), 2);
    assert_eq!(found[0].name, "main");
    assert_eq!(found[0].framework, None);
    assert_eq!(found[1].name, "counts");
    assert_eq!(found[1].framework, Some(TestFramework::Cargo));
}

#[test]
fn rust_module_file_test_keeps_file_module() {
    let text = "/// Adds.\n#[test]\nfn adds() {\n    assert!(true);\n}\n";
    let found = markers("/p/src/util.rs", text);
    assert_eq!(found.len(), 1);
    assert_eq!(found[0].name, "util::adds");
}

#[test]
fn plain_rust_function_has_no_marker() {
    let found = markers("/p/src/util.rs", "fn helper() {\n    let _ = 1;\n}\n");
    assert!(found.is_empty());
}

#[test]
fn cpp_macros_carry_their_framework() {
    let text = "#include <x.h>\n\nTEST(Geo, Area) {\n}\n\nTEST_F(GeoFixture, Perimeter) {\n}\n\nTEST_CASE(\"areas add up\", \"[geo]\") {\n}\n\n  TEST(Indented, Skipped) {\n}\n";
    let found = markers("/p/src/geo.cpp", text);
    let names: Vec<&str> = found.iter().map(|m| m.name.as_str()).collect();
    assert_eq!(names, ["Geo.Area", "GeoFixture.Perimeter", "areas add up"]);
    assert_eq!(found[0].framework, Some(TestFramework::GoogleTest));
    assert_eq!(found[1].framework, Some(TestFramework::GoogleTest));
    assert_eq!(found[2].framework, Some(TestFramework::Catch2));
    assert_eq!(
        text[found[2].byte_start as usize..].lines().next(),
        Some("TEST_CASE(\"areas add up\", \"[geo]\") {")
    );
}

#[test]
fn rust_block_comments_hide_tests() {
    let text = "/*\n#[test]\nfn commented() {\n}\n*/\n#[test]\nfn real() {\n}\n";
    let found = markers("/p/src/util.rs", text);
    assert_eq!(found.len(), 1);
    assert_eq!(found[0].name, "util::real");
}

#[test]
fn rust_inline_block_comment_hides_a_test() {
    let text = "/* #[test] fn hidden() {} */\n#[test]\nfn real() {\n}\n";
    let found = markers("/p/src/util.rs", text);
    let names: Vec<&str> = found.iter().map(|m| m.name.as_str()).collect();
    assert_eq!(names, ["util::real"]);
}
