use crate::highlight::Lang;

use super::tests::plan;

#[test]
fn refuses_inside_an_expression_closure() {
    let src = "fn main() {\n    let v: Vec<i32> = xs.iter().map(|x| x * 2).collect();\n}\n";
    assert!(plan(Lang::Rust, src, "x * 2").is_none());
}

#[test]
fn allows_inside_a_block_closure() {
    let src = "fn main() {\n    let f = |x: i32| {\n        x * 2\n    };\n}\n";
    assert!(plan(Lang::Rust, src, "x * 2").is_some());
}

#[test]
fn refuses_a_match_arm_value() {
    let src = "fn main() {\n    let n = match o {\n        Some(v) => v + 1,\n        None => 0,\n    };\n}\n";
    assert!(plan(Lang::Rust, src, "v + 1").is_none());
}

#[test]
fn refuses_a_loop_condition() {
    let src = "fn main() {\n    while i < n {\n        i += 1;\n    }\n}\n";
    assert!(plan(Lang::Rust, src, "i < n").is_none());
}

#[test]
fn refuses_an_else_if_condition() {
    let src = "fn main() {\n    if a {\n    } else if b * 2 > 3 {\n    }\n}\n";
    assert!(plan(Lang::Rust, src, "b * 2").is_none());
}

#[test]
fn refuses_the_right_side_of_a_short_circuit() {
    let src = "fn main() {\n    if !v.is_empty() && v[0] == 1 {\n    }\n}\n";
    assert!(plan(Lang::Rust, src, "v[0] == 1").is_none());
    assert!(plan(Lang::Rust, src, "!v.is_empty()").is_some());
}

#[test]
fn refuses_a_cpp_case_label() {
    let src = "int f(int k) {\n    switch (k) {\n    case 2 * 3:\n        return 1;\n    }\n    return 0;\n}\n";
    assert!(plan(Lang::Cpp, src, "2 * 3").is_none());
}

#[test]
fn refuses_a_method_name() {
    let src = "fn main() {\n    let n = v.len();\n}\n";
    assert!(plan(Lang::Rust, src, "len").is_none());
}

#[test]
fn refuses_a_let_pattern() {
    let src = "fn main() {\n    let x = 5;\n}\n";
    assert!(plan(Lang::Rust, src, "x").is_none());
}

#[test]
fn refuses_a_macro_name() {
    let src = "fn main() {\n    let s = format!(\"{}\", 1);\n}\n";
    assert!(plan(Lang::Rust, src, "format").is_none());
}

#[test]
fn refuses_plain_c() {
    let src = "int main(void) {\n    int n = w * h + 1;\n    return n;\n}\n";
    assert!(plan(Lang::C, src, "w * h").is_none());
}
