use crate::highlight::Lang;

use super::tests_apply::applied;
use super::tests_inline::plan;

fn inlined(lang: Lang, src: &str, needle: &str) -> Option<String> {
    plan(lang, src, needle).map(|p| applied(src, &p))
}

#[test]
fn closure_parameters_with_the_same_name_are_left_alone() {
    let src = "fn main() {\n    let x = 5;\n    let v = xs.map(|x| x + 1);\n    let y = x;\n}\n";
    assert_eq!(
        inlined(Lang::Rust, src, "x = 5").unwrap(),
        "fn main() {\n    let v = xs.map(|x| x + 1);\n    let y = 5;\n}\n"
    );
}

#[test]
fn struct_shorthand_is_expanded() {
    let src = "fn main() {\n    let n = 3;\n    let p = Point { n };\n}\n";
    assert_eq!(
        inlined(Lang::Rust, src, "n = 3").unwrap(),
        "fn main() {\n    let p = Point { n: 3 };\n}\n"
    );
}

#[test]
fn refuses_when_the_initializer_would_be_captured() {
    let src = "fn main() {\n    let x = a;\n    let f = |a: i32| a + x;\n}\n";
    assert!(plan(Lang::Rust, src, "x = a").is_none());
}

#[test]
fn refuses_when_an_initializer_name_is_rebound_before_a_use() {
    let src = "fn main() {\n    let x = a;\n    let a = 2;\n    f(x);\n}\n";
    assert!(plan(Lang::Rust, src, "x = a").is_none());
}

#[test]
fn refuses_when_the_initializer_is_mutated_before_a_use() {
    let src = "fn main() {\n    let x = a;\n    a += 1;\n    f(x);\n}\n";
    assert!(plan(Lang::Rust, src, "x = a").is_none());
}

#[test]
fn refuses_a_format_string_inline_use() {
    let src = "fn main() {\n    let x = 1;\n    println!(\"{x}\");\n    f(x);\n}\n";
    assert!(plan(Lang::Rust, src, "x = 1").is_none());
}

#[test]
fn parenthesizes_ranges_casts_and_closures_in_operand_position() {
    let src = "fn main() {\n    let r = 0..n;\n    let k = r.len();\n}\n";
    assert_eq!(
        inlined(Lang::Rust, src, "r = 0").unwrap(),
        "fn main() {\n    let k = (0..n).len();\n}\n"
    );
    let src = "fn main() {\n    let c = b as u32;\n    let k = c + 1;\n}\n";
    assert_eq!(
        inlined(Lang::Rust, src, "c = b").unwrap(),
        "fn main() {\n    let k = (b as u32) + 1;\n}\n"
    );
    let src = "fn main() {\n    let f = |v: i32| v + 1;\n    let k = f(2);\n}\n";
    assert_eq!(
        inlined(Lang::Rust, src, "f = |").unwrap(),
        "fn main() {\n    let k = (|v: i32| v + 1)(2);\n}\n"
    );
}

#[test]
fn a_binary_initializer_is_not_wrapped_when_standing_alone() {
    let src = "fn main() {\n    let x = a + b;\n    f(x);\n}\n";
    assert_eq!(
        inlined(Lang::Rust, src, "x = a").unwrap(),
        "fn main() {\n    f(a + b);\n}\n"
    );
}

#[test]
fn c_refuses_a_declarator_without_initializer_in_the_same_statement() {
    let src = "int main(void) {\n    int count, total = 0;\n    return total + count;\n}\n";
    assert!(plan(Lang::C, src, "total = 0").is_none());
}
