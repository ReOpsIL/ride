use crate::ffi::ExtractPlan;
use crate::highlight::{BufferSession, Lang};

use super::extract_variable;

fn plan(lang: Lang, text: &str, needle: &str) -> Option<ExtractPlan> {
    let (session, _) = BufferSession::open_lang(lang, text.to_string(), None).unwrap();
    let start = text.find(needle).unwrap() as u32;
    extract_variable(&session, start, start + needle.len() as u32)
}

fn applied(text: &str, plan: &ExtractPlan) -> String {
    let mut out = text.to_string();
    for edit in plan.edits.iter().rev() {
        out.replace_range(edit.start_byte as usize..edit.end_byte as usize, &edit.text);
    }
    out
}

const RUST_SRC: &str = "fn main() {\n    let x = a * b + c;\n    println!(\"{x}\");\n}\n";

#[test]
fn rust_binary_expression() {
    let plan = plan(Lang::Rust, RUST_SRC, "a * b").unwrap();
    assert_eq!(plan.name, "value");
    let out = applied(RUST_SRC, &plan);
    assert!(
        out.contains("    let value = a * b;\n    let x = value + c;"),
        "{out}"
    );
    assert_eq!(
        &out[plan.select_start as usize..plan.select_end as usize],
        "value"
    );
}

#[test]
fn rust_call_expression() {
    let src = "fn main() {\n    let n = total(1, 2) + 3;\n}\n";
    let plan = plan(Lang::Rust, src, "total(1, 2)").unwrap();
    let out = applied(src, &plan);
    assert!(
        out.contains("    let value = total(1, 2);\n    let n = value + 3;"),
        "{out}"
    );
}

#[test]
fn rust_trims_surrounding_whitespace() {
    let start = RUST_SRC.find("a * b").unwrap() as u32;
    let (session, _) = BufferSession::open_lang(Lang::Rust, RUST_SRC.to_string(), None).unwrap();
    let plan = extract_variable(&session, start - 1, start + 6).unwrap();
    let out = applied(RUST_SRC, &plan);
    assert!(out.contains("let value = a * b;"), "{out}");
}

#[test]
fn rust_refuses_two_statements() {
    let src = "fn main() {\n    let a = 1;\n    let b = 2;\n}\n";
    assert!(plan(Lang::Rust, src, "let a = 1;\n    let b = 2;").is_none());
}

#[test]
fn rust_refuses_outside_a_body() {
    let src = "const N: i32 = 1 + 2;\n";
    assert!(plan(Lang::Rust, src, "1 + 2").is_none());
}

#[test]
fn rust_second_placeholder() {
    let src = "fn main() {\n    let value = 0;\n    let x = a * b + c;\n}\n";
    let plan = plan(Lang::Rust, src, "a * b").unwrap();
    assert_eq!(plan.name, "value2");
    let out = applied(src, &plan);
    assert!(
        out.contains("    let value2 = a * b;\n    let x = value2 + c;"),
        "{out}"
    );
}

#[test]
fn cpp_uses_auto_and_keeps_indent() {
    let src = "int main() {\n    if (true) {\n        int n = w * h + 1;\n    }\n}\n";
    let plan = plan(Lang::Cpp, src, "w * h").unwrap();
    let out = applied(src, &plan);
    assert!(
        out.contains("        auto value = w * h;\n        int n = value + 1;"),
        "{out}"
    );
    assert_eq!(
        &out[plan.select_start as usize..plan.select_end as usize],
        "value"
    );
}

#[test]
fn cpp_return_call_expression() {
    let src = "int main() {\n    return abs(x - y) < 2;\n}\n";
    let plan = plan(Lang::Cpp, src, "abs(x - y)").unwrap();
    let out = applied(src, &plan);
    assert!(
        out.contains("    auto value = abs(x - y);\n    return value < 2;"),
        "{out}"
    );
}

#[test]
fn unsupported_language_refuses() {
    let src = "# a * b\n";
    assert!(plan(Lang::Markdown, src, "a * b").is_none());
}
