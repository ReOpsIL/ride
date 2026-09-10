use std::fs;
use std::path::PathBuf;

use ride_engine::{DiagnosticLevel, Lang, parse_clang, run_clang_check, tool_path};

fn scratch(name: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("ride-clang-{}-{name}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    dir
}

fn clang_available() -> bool {
    tool_path("clang").is_file()
}

#[test]
fn header_with_cpp_constructs_opens_as_cpp() {
    assert_eq!(
        Lang::for_buffer(Some("a.h"), "namespace geo {\n}\n"),
        Lang::Cpp
    );
    assert_eq!(
        Lang::for_buffer(Some("a.h"), "#include <vector>\n"),
        Lang::Cpp
    );
    assert_eq!(
        Lang::for_buffer(Some("a.h"), "  template <typename T>\nT id(T);\n"),
        Lang::Cpp
    );
    assert_eq!(
        Lang::for_buffer(Some("a.h"), "struct S {\npublic:\n int x;\n};\n"),
        Lang::Cpp
    );
}

#[test]
fn plain_c_header_stays_c() {
    let src = "#include <stdio.h>\n#include <sys/types.h>\n/* using the api */\nint f(void);\n";
    assert_eq!(Lang::for_buffer(Some("a.h"), src), Lang::C);
    assert_eq!(Lang::for_buffer(Some("a.c"), "namespace x {}"), Lang::C);
    assert_eq!(Lang::for_buffer(Some("a.hpp"), "int x;"), Lang::Cpp);
}

#[test]
fn parses_clang_lines_with_ranges_codes_and_notes() {
    let dir = scratch("parse");
    let file = dir.join("m.c");
    fs::write(&file, "int f(void) {\n  int unused = 1;\n  return y;\n}\n").unwrap();
    let path = file.display();
    let text = format!(
        "In file included from {path}:1:\n\
         {path}:2:7:{{2:7-2:13}}: warning: unused variable 'unused' [-Wunused-variable]\n\
         {path}:3:10:{{3:10-3:11}}: error: use of undeclared identifier 'y'\n\
         {path}:3:10: note: did you mean 'f'?\n\
         {path}:3:10:{{3:10-3:11}}: error: use of undeclared identifier 'y'\n\
         2 diagnostics generated.\n"
    );
    let diags = parse_clang(&text);
    assert_eq!(diags.len(), 3, "{diags:?}");
    let warn = &diags[0];
    assert_eq!(warn.level, DiagnosticLevel::Warning);
    assert_eq!(warn.code.as_deref(), Some("-Wunused-variable"));
    assert_eq!(warn.message, "unused variable 'unused'");
    assert_eq!((warn.line, warn.column), (2, 7));
    assert_eq!((warn.byte_start, warn.byte_end), (20, 26));
    let err = &diags[1];
    assert_eq!(err.level, DiagnosticLevel::Error);
    assert_eq!(err.code, None);
    assert_eq!((err.byte_start, err.byte_end), (41, 42));
    assert_eq!(err.path, path.to_string());
    assert_eq!(diags[2].level, DiagnosticLevel::Note);
    assert_eq!((diags[2].byte_start, diags[2].byte_end), (41, 41));
}

#[test]
fn warnings_carry_their_flag_as_code() {
    if !clang_available() {
        return;
    }
    let dir = scratch("warn");
    let file = dir.join("w.c");
    fs::write(&file, "int main(void) { int x; return 0; }\n").unwrap();
    let result = run_clang_check(&file).unwrap();
    assert!(result.success);
    let warn = &result.diagnostics[0];
    assert_eq!(warn.level, DiagnosticLevel::Warning);
    assert_eq!(warn.code.as_deref(), Some("-Wunused-variable"));
    assert_eq!((warn.byte_start, warn.byte_end), (21, 22));
}

#[test]
fn runs_clang_on_a_c_file_without_a_database() {
    if !clang_available() {
        return;
    }
    let dir = scratch("run");
    let file = dir.join("t.c");
    fs::write(&file, "int main(void) { int x; return y; }\n").unwrap();
    let result = run_clang_check(&file).unwrap();
    assert!(!result.success);
    let err = result
        .diagnostics
        .iter()
        .find(|d| d.level == DiagnosticLevel::Error)
        .unwrap();
    assert_eq!((err.line, err.column), (1, 32));
    assert_eq!((err.byte_start, err.byte_end), (31, 32));
    assert!(err.message.contains("undeclared identifier 'y'"), "{err:?}");
}

#[test]
fn runs_clang_on_a_cpp_file_with_std_headers() {
    if !clang_available() {
        return;
    }
    let dir = scratch("cpp");
    let file = dir.join("t.cpp");
    fs::write(
        &file,
        "#include <vector>\nint main() { std::vector<int> v; return v; }\n",
    )
    .unwrap();
    let result = run_clang_check(&file).unwrap();
    assert!(!result.success);
    assert!(
        result
            .diagnostics
            .iter()
            .any(|d| d.line == 2 && d.level == DiagnosticLevel::Error)
    );
}

#[test]
fn compile_database_supplies_flags_for_the_file_and_its_headers() {
    if !clang_available() {
        return;
    }
    let dir = scratch("db");
    let src = dir.join("main.c");
    let hdr = dir.join("main.h");
    fs::write(
        &src,
        "#include \"main.h\"\nint main(void) { return VALUE; }\n",
    )
    .unwrap();
    fs::write(&hdr, "#if !defined(VALUE)\n#error missing VALUE\n#endif\n").unwrap();
    let db = format!(
        "[{{\"directory\": \"{}\", \"file\": \"main.c\", \"command\": \"cc -DVALUE=1 -c main.c -o main.o\"}}]",
        dir.display()
    );
    fs::write(dir.join("compile_commands.json"), db).unwrap();
    let result = run_clang_check(&src).unwrap();
    assert!(result.success, "{:?}", result.stderr_tail);
    assert!(result.diagnostics.is_empty());
    assert!(!dir.join("main.o").exists());
    let header = run_clang_check(&hdr).unwrap();
    assert!(header.success, "{:?}", header.stderr_tail);
}

#[test]
fn missing_database_reports_the_error_from_the_header() {
    if !clang_available() {
        return;
    }
    let dir = scratch("nodb");
    let hdr = dir.join("only.h");
    fs::write(&hdr, "#if !defined(VALUE)\n#error missing VALUE\n#endif\n").unwrap();
    let result = run_clang_check(&hdr).unwrap();
    assert!(!result.success);
    assert_eq!(result.diagnostics[0].line, 2);
    assert_eq!(result.diagnostics[0].message, "missing VALUE");
}
