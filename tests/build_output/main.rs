use std::path::{Path, PathBuf};
use std::sync::Arc;

use ride_engine::{DiagnosticLevel, Engine, EngineConfig, engine_start};

mod diag;

use diag::{byte_of, loc, src};

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
        refs_dir: None,
        report_dir: None,
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
    let diags = engine.parse_cargo_line(fixture("cargo-error.json"), root.display().to_string());
    assert_eq!(diags.len(), 1);
    assert_eq!(
        diags[0].primary.path,
        root.join("src/main.rs").display().to_string()
    );
    assert_eq!(diags[0].level, DiagnosticLevel::Error);
    assert_eq!(diags[0].code.as_deref(), Some("E0308"));
    assert_eq!(diags[0].message, "mismatched types");
    assert_eq!(diags[0].primary.line_start, 3);
    assert_eq!(diags[0].primary.column, 18);
    assert!(diags[0].primary.byte_end > diags[0].primary.byte_start);
}

#[test]
fn cargo_warning_line_carries_the_lint_name() {
    let (engine, root) = opened_on_demo();
    let diags = engine.parse_cargo_line(fixture("cargo-warning.json"), root.display().to_string());
    assert_eq!(diags.len(), 1);
    assert_eq!(diags[0].level, DiagnosticLevel::Warning);
    assert_eq!(diags[0].code.as_deref(), Some("unused_variables"));
    assert!(diags[0].message.contains("unused variable"));
    assert_eq!(diags[0].primary.line_start, 2);
}

#[test]
fn non_message_lines_are_ignored() {
    let engine = engine();
    assert!(
        engine
            .parse_cargo_line(
                "{\"reason\":\"build-finished\",\"success\":false}".into(),
                String::new()
            )
            .is_empty()
    );
    assert!(
        engine
            .parse_cargo_line("Compiling q4demo v0.1.0".into(), String::new())
            .is_empty()
    );
    assert!(
        engine
            .parse_cargo_line(String::new(), String::new())
            .is_empty()
    );
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
    assert!(diags.iter().all(|d| src(d) == source.display().to_string()));
    assert_eq!(diags[0].code.as_deref(), Some("-Wunused-variable"));
    assert_eq!(diags[0].message, "unused variable 'unused_local'");
    assert_eq!(diags[1].message, "redefinition of 'twice'");
    assert_eq!(loc(&diags[1]), (7, 12));
    assert_eq!(diags[2].message, "previous definition is here");
    assert_eq!(diags[2].primary.line_start, 6);
    assert_eq!(byte_of(&source, 7, 12), diags[1].primary.byte_start);
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
    assert!(diags.iter().all(|d| src(d) == source.display().to_string()));
    assert_eq!(byte_of(&source, 7, 12), diags[1].primary.byte_start);
    assert_eq!(diags[0].message, "unused variable 'unused_local'");
}

#[test]
fn member_crate_diagnostics_resolve_against_the_workspace_root() {
    let engine = engine();
    let member =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/workspace_members/app");
    let info = engine.open_workspace(member.display().to_string()).unwrap();
    let diags = engine.parse_cargo_line(fixture("cargo-error.json"), member.display().to_string());
    assert_eq!(diags.len(), 1);
    assert_eq!(
        diags[0].primary.path,
        Path::new(&info.workspace_root)
            .join("src/main.rs")
            .display()
            .to_string()
    );
    assert!(!src(&diags[0]).starts_with(&member.display().to_string()));
}

#[test]
fn nested_crate_diagnostics_resolve_against_the_nested_crate() {
    let folder = tempfile::tempdir().unwrap();
    let lesson = folder.path().join("lesson01");
    std::fs::create_dir_all(lesson.join("src")).unwrap();
    std::fs::write(
        lesson.join("Cargo.toml"),
        "[package]\nname = \"lesson01\"\nversion = \"0.1.0\"\nedition = \"2021\"\n",
    )
    .unwrap();
    std::fs::write(lesson.join("src/main.rs"), "fn main() {}\n").unwrap();
    let engine = engine();
    engine
        .open_workspace(folder.path().display().to_string())
        .unwrap();
    let diags = engine.parse_cargo_line(fixture("cargo-error.json"), lesson.display().to_string());
    assert_eq!(diags.len(), 1);
    let expected = lesson.canonicalize().unwrap().join("src/main.rs");
    assert_eq!(
        Path::new(&diags[0].primary.path)
            .canonicalize()
            .ok()
            .unwrap_or_default(),
        expected
    );
}
