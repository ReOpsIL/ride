use std::path::{Path, PathBuf};

use ride_engine::{
    DiagnosticLevel, Formatter, Lang, format_document, format_range, format_source, parse_lines,
    run_check,
};

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

#[test]
fn makefile_formatter_normalizes_recipes() {
    let src = "CC := cc\n\n\n\nall: main.o\n    $(CC) -o app main.o   \n  @echo done\n\nifeq ($(OS),Windows_NT)\n    EXE := .exe\nendif\n\ndefine msg\n    echo hi\nendef\n";
    let out = ride_engine::format_make(src);
    assert_eq!(
        out,
        "CC := cc\n\nall: main.o\n\t$(CC) -o app main.o\n\t@echo done\n\nifeq ($(OS),Windows_NT)\n    EXE := .exe\nendif\n\ndefine msg\n    echo hi\nendef\n"
    );
    assert_eq!(ride_engine::format_make(&out), out);
}

#[test]
fn clang_format_selection_changes_only_selected_function() {
    if !Formatter::ClangFormat.available() {
        return;
    }
    let src = "int  foo( ){return 1;}\nint  bar( ){return 2;}\n";
    let foo_end = src.find('\n').unwrap() as u32;
    let out = format_range(Lang::C, src, Some("a.c"), None, 0, foo_end).unwrap();
    assert!(out.contains("int foo()"), "{out}");
    assert!(
        out.contains("int  bar( ){return 2;}"),
        "unselected function changed:\n{out}"
    );
    assert!(!out.contains("int  foo( )"), "{out}");
}

#[test]
fn rustfmt_selection_formats_enclosing_fn_only() {
    let src = "fn  foo(){let x=1;}\nfn  bar(){let y=2;}\n";
    let caret = src.find("x=1").unwrap() as u32;
    let out = format_range(Lang::Rust, src, Some("a.rs"), None, caret, caret).unwrap();
    assert!(
        out.contains("fn foo() {\n    let x = 1;\n}"),
        "enclosing fn not formatted:\n{out}"
    );
    assert!(
        out.contains("fn  bar(){let y=2;}"),
        "unselected fn changed:\n{out}"
    );
}

#[test]
fn format_range_makefile_formats_whole_file() {
    let src = "all: x\n    cc x\n";
    let out = format_range(Lang::Make, src, Some("Makefile"), None, 0, 3).unwrap();
    assert_eq!(out, ride_engine::format_make(src));
}

#[test]
fn formatter_lookup_reports_tools_and_hints() {
    assert_eq!(Formatter::for_lang(Lang::Make), Some(Formatter::Builtin));
    assert!(Formatter::Builtin.available());
    assert!(Formatter::for_lang(Lang::Markdown).is_none());
    let err = format_document(Lang::Markdown, "x", None, None).unwrap_err();
    assert!(format!("{err:?}").contains("no formatter"));
    if std::path::Path::new("/Applications/Xcode.app").exists() {
        assert!(
            Formatter::ClangFormat.available(),
            "clang-format should be found in the Xcode toolchain"
        );
        let out = format_document(Lang::C, "int  main( ){return 0;}", Some("a.c"), None).unwrap();
        assert!(out.contains("int main()"));
    }
}
