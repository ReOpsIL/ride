use crate::highlight::Lang;

use super::tests_apply::applied;
use super::tests_constant::plan;

fn head(lang: Lang, src: &str, needle: &str) -> String {
    let out = applied(src, &plan(lang, src, needle).unwrap());
    out.lines().next().unwrap_or_default().to_string()
}

#[test]
fn literal_suffixes_decide_the_type() {
    let src = "fn main() {\n    let n = 5u8;\n    let f = 2.5f32;\n}\n";
    assert_eq!(head(Lang::Rust, src, "5u8"), "const VALUE: u8 = 5u8;");
    assert_eq!(
        head(Lang::Rust, src, "2.5f32"),
        "const VALUE: f32 = 2.5f32;"
    );
}

#[test]
fn byte_literals_are_bytes() {
    let src = "fn main() {\n    let c = b'a';\n    let s = b\"xy\";\n}\n";
    assert_eq!(head(Lang::Rust, src, "b'a'"), "const VALUE: u8 = b'a';");
    assert_eq!(
        head(Lang::Rust, src, "b\"xy\""),
        "const VALUE: &[u8] = b\"xy\";"
    );
}

#[test]
fn an_index_literal_is_usize() {
    let src = "fn main() {\n    let x = v[3];\n}\n";
    assert_eq!(head(Lang::Rust, src, "3"), "const VALUE: usize = 3;");
}

#[test]
fn impl_methods_place_the_constant_at_module_level() {
    let src = "struct S;\n\nimpl S {\n    fn f(&self) -> i32 {\n        42\n    }\n}\n";
    let out = applied(src, &plan(Lang::Rust, src, "42").unwrap());
    assert!(
        out.starts_with("struct S;\n\nconst VALUE: i32 = 42;\n\nimpl S {"),
        "{out}"
    );
}

#[test]
fn c_refuses_a_case_label() {
    let src = "int f(int k) {\n    switch (k) {\n    case 5:\n        return 1;\n    }\n    return 0;\n}\n";
    assert!(plan(Lang::C, src, "5").is_none());
    assert!(plan(Lang::Cpp, src, "5").is_some());
}
