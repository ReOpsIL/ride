use super::*;
use crate::highlight::{BufferSession, Lang};

fn gen_type(name: &str, src: &str) -> GenType {
    let (session, _) = BufferSession::open_lang(Lang::Cpp, src.to_string(), None).unwrap();
    let scope = session.scope();
    GenType::from_scope(name, &scope.types)
}

const RECT: &str = "using Real = double;\nclass Rect {\n    Real width_;\n    Real height_;\n};\n";

#[test]
fn fields_carry_declared_type() {
    let t = gen_type("Rect", RECT);
    let names: Vec<&str> = t.fields.iter().map(|f| f.name.as_str()).collect();
    assert_eq!(names, vec!["width_", "height_"]);
    assert!(t.fields.iter().all(|f| f.type_name == "Real"));
}

#[test]
fn constructor_has_params_and_init_list() {
    let text = cpp::constructor(&gen_type("Rect", RECT));
    assert!(text.contains("Rect(Real width, Real height)"), "{text}");
    assert!(text.contains(": width_(width), height_(height)"), "{text}");
}

#[test]
fn getters_one_per_field() {
    let text = cpp::getters(&gen_type("Rect", RECT));
    assert!(
        text.contains("Real width() const { return width_; }"),
        "{text}"
    );
    assert!(
        text.contains("Real height() const { return height_; }"),
        "{text}"
    );
}

#[test]
fn setters_one_per_field() {
    let text = cpp::setters(&gen_type("Rect", RECT));
    assert!(
        text.contains("void set_width(Real value) { width_ = value; }"),
        "{text}"
    );
}

#[test]
fn equality_pair() {
    let text = cpp::equality(&gen_type("Rect", RECT));
    assert!(
        text.contains("bool operator==(const Rect& other) const"),
        "{text}"
    );
    assert!(
        text.contains("width_ == other.width_ && height_ == other.height_"),
        "{text}"
    );
    assert!(
        text.contains("bool operator!=(const Rect& other) const"),
        "{text}"
    );
}

#[test]
fn stream_insert_operator() {
    let text = cpp::stream_insert(&gen_type("Rect", RECT));
    assert!(
        text.contains("friend std::ostream& operator<<(std::ostream& os, const Rect& v)"),
        "{text}"
    );
    assert!(text.contains("v.width_ << \", \" << v.height_"), "{text}");
}

#[test]
fn options_present_with_fields_absent_without() {
    assert_eq!(options(&gen_type("Rect", RECT), Lang::Cpp, RECT).len(), 5);
    assert!(
        options(
            &gen_type("Empty", "class Empty {};\n"),
            Lang::Cpp,
            "class Empty {};\n"
        )
        .is_empty()
    );
}

#[test]
fn getter_prefixes_without_underscore() {
    let src = "class Point {\npublic:\n    int x;\n};\n";
    let text = cpp::getters(&gen_type("Point", src));
    assert!(text.contains("int get_x() const { return x; }"), "{text}");
}

const DERIVED: &str =
    "class Base {\n    std::string tag_;\n};\nclass Derived : public Base {\n    int n_;\n};\n";

#[test]
fn own_fields_exclude_base() {
    let t = gen_type("Derived", DERIVED);
    let names: Vec<&str> = t.fields.iter().map(|f| f.name.as_str()).collect();
    assert_eq!(names, vec!["n_"]);
}

#[test]
fn constructor_omits_base_fields() {
    let text = cpp::constructor(&gen_type("Derived", DERIVED));
    assert!(text.contains("Derived(int n) : n_(n) {}"), "{text}");
    assert!(!text.contains("tag_"), "{text}");
}

#[test]
fn getter_keeps_namespace_qualifier() {
    let src = "class Person {\n    std::string name_;\n};\n";
    let text = cpp::getters(&gen_type("Person", src));
    assert!(
        text.contains("std::string name() const { return name_; }"),
        "{text}"
    );
}
