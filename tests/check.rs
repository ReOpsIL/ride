use std::path::{Path, PathBuf};

use ride_engine::{DiagnosticLevel, format_source, parse_lines, run_check};

fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

const LINES: &str = r#"{"reason":"compiler-artifact","target":{"name":"x"}}
{"reason":"compiler-message","message":{"message":"mismatched types","code":{"code":"E0308"},"level":"error","spans":[{"file_name":"src/main.rs","byte_start":40,"byte_end":45,"line_start":3,"line_end":3,"column_start":13,"column_end":18,"is_primary":true},{"file_name":"src/main.rs","byte_start":10,"byte_end":12,"line_start":1,"line_end":1,"column_start":1,"column_end":3,"is_primary":false}],"children":[]}}
{"reason":"compiler-message","message":{"message":"unused variable: `y`","code":null,"level":"warning","spans":[{"file_name":"/abs/lib.rs","byte_start":5,"byte_end":6,"line_start":2,"line_end":2,"column_start":9,"column_end":10,"is_primary":true}],"children":[]}}
{"reason":"compiler-message","message":{"message":"aborting due to 1 previous error","code":null,"level":"error","spans":[],"children":[]}}
{"reason":"build-finished","success":false}
"#;

#[test]
fn parses_primary_spans_only() {
    let diags = parse_lines(Path::new("/proj"), LINES);
    assert_eq!(diags.len(), 2);
    assert_eq!(diags[0].path, "/proj/src/main.rs");
    assert_eq!(diags[0].byte_start, 40);
    assert_eq!(diags[0].line, 3);
    assert_eq!(diags[0].level, DiagnosticLevel::Error);
    assert_eq!(diags[0].code.as_deref(), Some("E0308"));
    assert_eq!(diags[1].path, "/abs/lib.rs");
    assert_eq!(diags[1].level, DiagnosticLevel::Warning);
    assert!(diags[1].code.is_none());
}

#[test]
fn cargo_check_on_fixture_crate() {
    let target = tempfile::tempdir().unwrap();
    let result = run_check(&fixtures().join("sample_crate"), Some(target.path())).unwrap();
    assert!(result.success, "{}", result.stderr_tail);
    assert!(
        result
            .diagnostics
            .iter()
            .all(|d| d.level != DiagnosticLevel::Error)
    );
}

#[test]
fn rustfmt_formats_and_reports_errors() {
    let out = format_source("fn main(){let x=1;}", None).unwrap();
    assert_eq!(out, "fn main() {\n    let x = 1;\n}\n");
    assert!(format_source("fn main( {", None).is_err());
}

#[test]
fn tools_resolve_without_path() {
    let saved = std::env::var_os("PATH");
    unsafe { std::env::set_var("PATH", "/nonexistent") };
    let cargo = ride_engine::tool_path("cargo");
    let rustc = ride_engine::tool_path("rustc");
    if let Some(p) = saved {
        unsafe { std::env::set_var("PATH", p) };
    }
    assert!(cargo.is_absolute(), "{cargo:?}");
    assert!(rustc.is_absolute(), "{rustc:?}");
    assert!(cargo.is_file() && rustc.is_file());
}
