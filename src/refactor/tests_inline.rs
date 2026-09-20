use crate::ffi::ExtractPlan;
use crate::highlight::{BufferSession, Lang};

use super::inline_variable;
use super::tests_apply::{applied, selected};

fn plan(lang: Lang, text: &str, needle: &str) -> Option<ExtractPlan> {
    let (session, _) = BufferSession::open_lang(lang, text.to_string(), None).unwrap();
    let start = text.find(needle).unwrap() as u32;
    inline_variable(&session, start)
}

#[test]
fn rust_parenthesizes_a_binary_initializer() {
    let src = "fn main() {\n    let x = a + b;\n    let y = x * 2;\n}\n";
    let plan = plan(Lang::Rust, src, "x = a + b").unwrap();
    assert_eq!(plan.name, "x");
    let out = applied(src, &plan);
    assert_eq!(out, "fn main() {\n    let y = (a + b) * 2;\n}\n");
    assert_eq!(selected(&out, &plan), "(a + b)");
}

#[test]
fn rust_inlines_from_a_use_site() {
    let src = "fn main() {\n    let x = a + b;\n    let y = x * 2;\n}\n";
    let start = src.find("x * 2").unwrap() as u32;
    let (session, _) = BufferSession::open_lang(Lang::Rust, src.to_string(), None).unwrap();
    let out = applied(src, &inline_variable(&session, start).unwrap());
    assert_eq!(out, "fn main() {\n    let y = (a + b) * 2;\n}\n");
}

#[test]
fn rust_plain_initializer_is_not_wrapped() {
    let src = "fn main() {\n    let x = 3;\n    let y = x;\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "x = 3").unwrap());
    assert_eq!(out, "fn main() {\n    let y = 3;\n}\n");
}

#[test]
fn rust_refuses_a_call_initializer() {
    let src = "fn main() {\n    let x = foo();\n    let y = x;\n}\n";
    assert!(plan(Lang::Rust, src, "x = foo").is_none());
}

#[test]
fn rust_refuses_a_macro_initializer() {
    let src = "fn main() {\n    let x = vec![1];\n    let y = x;\n}\n";
    assert!(plan(Lang::Rust, src, "x = vec").is_none());
}

#[test]
fn rust_refuses_mut() {
    let src = "fn main() {\n    let mut x = 1;\n    let y = x;\n}\n";
    assert!(plan(Lang::Rust, src, "x = 1").is_none());
}

#[test]
fn rust_refuses_an_assigned_local() {
    let src = "fn main() {\n    let x = 1;\n    x = 2;\n    let y = x;\n}\n";
    assert!(plan(Lang::Rust, src, "x = 1").is_none());
}

#[test]
fn rust_refuses_without_a_use() {
    let src = "fn main() {\n    let x = 1;\n}\n";
    assert!(plan(Lang::Rust, src, "x = 1").is_none());
}

#[test]
fn rust_keeps_a_shared_line() {
    let src = "fn main() {\n    let a = 0; let x = 1;\n    let y = x;\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "x = 1").unwrap());
    assert_eq!(out, "fn main() {\n    let a = 0; \n    let y = 1;\n}\n");
}

#[test]
fn c_inlines_a_declaration() {
    let src = "int main() {\n    int n = 3;\n    return n + n;\n}\n";
    let plan = plan(Lang::C, src, "n = 3").unwrap();
    let out = applied(src, &plan);
    assert_eq!(out, "int main() {\n    return 3 + 3;\n}\n");
    assert_eq!(selected(&out, &plan), "3");
}

#[test]
fn cpp_parenthesizes_a_binary_initializer() {
    let src = "int main() {\n    double d = 2 + 3;\n    return d + 4;\n}\n";
    let out = applied(src, &plan(Lang::Cpp, src, "d = 2 + 3").unwrap());
    assert_eq!(out, "int main() {\n    return (2 + 3) + 4;\n}\n");
}

#[test]
fn c_refuses_several_declarators() {
    let src = "int main() {\n    int n = 3, m = 4;\n    return n + m;\n}\n";
    assert!(plan(Lang::C, src, "n = 3").is_none());
}

#[test]
fn unsupported_language_refuses() {
    assert!(plan(Lang::Markdown, "let x = 1;\n", "x = 1").is_none());
}
