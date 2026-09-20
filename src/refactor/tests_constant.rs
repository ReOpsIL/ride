use crate::ffi::ExtractPlan;
use crate::highlight::{BufferSession, Lang};

use super::introduce_constant;
use super::tests_apply::{applied, selected};

fn plan(lang: Lang, text: &str, needle: &str) -> Option<ExtractPlan> {
    let (session, _) = BufferSession::open_lang(lang, text.to_string(), None).unwrap();
    let start = text.find(needle).unwrap() as u32;
    introduce_constant(&session, start, start + needle.len() as u32)
}

const RUST_SRC: &str = "fn main() {\n    let n = 42;\n}\n";

#[test]
fn rust_integer_literal() {
    let plan = plan(Lang::Rust, RUST_SRC, "42").unwrap();
    assert_eq!(plan.name, "VALUE");
    let out = applied(RUST_SRC, &plan);
    assert!(
        out.starts_with("const VALUE: i32 = 42;\n\nfn main() {\n    let n = VALUE;"),
        "{out}"
    );
    assert_eq!(selected(&out, &plan), "VALUE");
}

#[test]
fn rust_string_literal() {
    let src = "fn main() {\n    let s = \"ride\";\n}\n";
    let plan = plan(Lang::Rust, src, "\"ride\"").unwrap();
    let out = applied(src, &plan);
    assert!(
        out.starts_with("const VALUE: &str = \"ride\";\n\n"),
        "{out}"
    );
    assert!(out.contains("let s = VALUE;"), "{out}");
}

#[test]
fn rust_float_and_bool() {
    let src = "fn main() {\n    let f = 1.5;\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "1.5").unwrap());
    assert!(out.starts_with("const VALUE: f64 = 1.5;"), "{out}");
    let src = "fn main() {\n    let b = true;\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "true").unwrap());
    assert!(out.starts_with("const VALUE: bool = true;"), "{out}");
}

#[test]
fn rust_wide_integers() {
    let src = "fn main() {\n    let n = 5000000000;\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "5000000000").unwrap());
    assert!(out.starts_with("const VALUE: i64 = 5000000000;"), "{out}");
    let src = "fn main() {\n    let n = 18000000000000000000;\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "18000000000000000000").unwrap());
    assert!(out.starts_with("const VALUE: u64 = 1800"), "{out}");
}

#[test]
fn rust_negative_literal() {
    let src = "fn main() {\n    let n = -7;\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "-7").unwrap());
    assert!(out.starts_with("const VALUE: i32 = -7;"), "{out}");
}

#[test]
fn rust_refuses_non_literal() {
    let src = "fn main() {\n    let n = a + b;\n}\n";
    assert!(plan(Lang::Rust, src, "a + b").is_none());
}

#[test]
fn rust_second_placeholder() {
    let src = "const VALUE: i32 = 1;\n\nfn main() {\n    let n = 42;\n}\n";
    let plan = plan(Lang::Rust, src, "42").unwrap();
    assert_eq!(plan.name, "VALUE2");
}

#[test]
fn rust_indents_inside_a_module() {
    let src = "mod inner {\n    fn main() {\n        let n = 42;\n    }\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "42").unwrap());
    assert!(
        out.contains("    const VALUE: i32 = 42;\n\n    fn main() {"),
        "{out}"
    );
}

#[test]
fn cpp_constexpr() {
    let src = "int main() {\n    int n = 42;\n}\n";
    let plan = plan(Lang::Cpp, src, "42").unwrap();
    let out = applied(src, &plan);
    assert!(
        out.starts_with("constexpr int VALUE = 42;\n\nint main() {\n    int n = VALUE;"),
        "{out}"
    );
    assert_eq!(selected(&out, &plan), "VALUE");
}

#[test]
fn cpp_double_and_string() {
    let src = "int main() {\n    double d = 1e-9;\n}\n";
    let out = applied(src, &plan(Lang::Cpp, src, "1e-9").unwrap());
    assert!(out.starts_with("constexpr double VALUE = 1e-9;"), "{out}");
    let src = "int main() {\n    auto s = \"ride\";\n}\n";
    let out = applied(src, &plan(Lang::Cpp, src, "\"ride\"").unwrap());
    assert!(
        out.starts_with("constexpr const char* VALUE = \"ride\";"),
        "{out}"
    );
}

#[test]
fn c_static_const() {
    let src = "int main() {\n    int n = 42;\n}\n";
    let out = applied(src, &plan(Lang::C, src, "42").unwrap());
    assert!(out.starts_with("static const int VALUE = 42;\n\n"), "{out}");
}

#[test]
fn unsupported_language_refuses() {
    assert!(plan(Lang::Markdown, "# 42\n", "42").is_none());
}
