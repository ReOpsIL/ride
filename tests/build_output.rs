use std::path::{Path, PathBuf};
use std::sync::Arc;

use ride_engine::{DiagnosticLevel, Engine, EngineConfig, engine_start};

fn fixture(name: &str) -> String {
    std::fs::read_to_string(fixtures().join(name)).unwrap()
}

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/build")
}

fn engine() -> Arc<Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn opened_on_demo() -> (Arc<Engine>, PathBuf) {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/rust-demo");
    let engine = engine();
    engine.open_workspace(root.display().to_string()).unwrap();
    (engine, root)
}

#[test]
fn cargo_error_line_yields_one_primary_diagnostic() {
    let (engine, root) = opened_on_demo();
    let diags = engine.parse_cargo_line(fixture("cargo-error.json"));
    assert_eq!(diags.len(), 1);
    assert_eq!(
        diags[0].path,
        root.join("src/main.rs").display().to_string()
    );
    assert_eq!(diags[0].level, DiagnosticLevel::Error);
    assert_eq!(diags[0].code.as_deref(), Some("E0308"));
    assert_eq!(diags[0].message, "mismatched types");
    assert_eq!(diags[0].line, 3);
    assert_eq!(diags[0].column, 18);
    assert!(diags[0].byte_end > diags[0].byte_start);
}

#[test]
fn cargo_warning_line_carries_the_lint_name() {
    let (engine, _) = opened_on_demo();
    let diags = engine.parse_cargo_line(fixture("cargo-warning.json"));
    assert_eq!(diags.len(), 1);
    assert_eq!(diags[0].level, DiagnosticLevel::Warning);
    assert_eq!(diags[0].code.as_deref(), Some("unused_variables"));
    assert!(diags[0].message.contains("unused variable"));
    assert_eq!(diags[0].line, 2);
}

#[test]
fn non_message_lines_are_ignored() {
    let engine = engine();
    assert!(
        engine
            .parse_cargo_line("{\"reason\":\"build-finished\",\"success\":false}".into())
            .is_empty()
    );
    assert!(
        engine
            .parse_cargo_line("Compiling q4demo v0.1.0".into())
            .is_empty()
    );
    assert!(engine.parse_cargo_line(String::new()).is_empty());
}

#[test]
fn clang_output_yields_warning_error_and_note() {
    let engine = engine();
    let source = fixtures().join("demo.cpp");
    let text = fixture("clang-output.txt").replace("demo.cpp:", &format!("{}:", source.display()));
    let diags = engine.parse_clang_output(text, String::new());
    assert_eq!(diags.len(), 3);
    let levels: Vec<_> = diags.iter().map(|d| d.level).collect();
    assert_eq!(
        levels,
        vec![
            DiagnosticLevel::Warning,
            DiagnosticLevel::Error,
            DiagnosticLevel::Note
        ]
    );
    assert!(diags.iter().all(|d| d.path == source.display().to_string()));
    assert_eq!(diags[0].code.as_deref(), Some("-Wunused-variable"));
    assert_eq!(diags[0].message, "unused variable 'unused_local'");
    assert_eq!(diags[1].message, "redefinition of 'twice'");
    assert_eq!((diags[1].line, diags[1].column), (7, 12));
    assert_eq!(diags[2].message, "previous definition is here");
    assert_eq!(diags[2].line, 6);
    assert_eq!(byte_of(&source, 7, 12), diags[1].byte_start);
}

#[test]
fn clang_output_without_locations_is_empty() {
    let engine = engine();
    assert!(
        engine
            .parse_clang_output("1 warning and 1 error generated.\n".into(), String::new())
            .is_empty()
    );
}

#[test]
fn clang_relative_paths_resolve_against_the_base_dir() {
    let engine = engine();
    let source = fixtures().join("demo.cpp");
    let diags = engine.parse_clang_output(
        fixture("clang-output.txt"),
        fixtures().display().to_string(),
    );
    assert_eq!(diags.len(), 3);
    assert!(diags.iter().all(|d| d.path == source.display().to_string()));
    assert_eq!(byte_of(&source, 7, 12), diags[1].byte_start);
    assert_eq!(diags[0].message, "unused variable 'unused_local'");
}

fn byte_of(path: &Path, line: u32, column: u32) -> u32 {
    let text = std::fs::read_to_string(path).unwrap();
    let start: u32 = text
        .split_inclusive('\n')
        .take(line as usize - 1)
        .map(|l| l.len() as u32)
        .sum();
    start + column - 1
}
