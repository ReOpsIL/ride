mod oracle_support;

use oracle_support::{Probe, names};

const HEADER: &str = "#pragma once\n#include <string>\nnamespace geo {\nclass Rect {\npublic:\n    Rect(double w, double h) : w_(w), h_(h) {}\n    double area() const { return w_ * h_; }\n    bool is_square() const { return w_ == h_; }\nprivate:\n    double w_;\n    double h_;\n};\nvoid scale_all(double factor);\n}\n";

const MAIN: &str = "#include <shapes.hpp>\n#include <string>\n#include <vector>\n\nint main() {\n    std::vector<geo::Rect> rects = {geo::Rect(1, 2)};\n    auto it = rects.begin();\n    it->is\n    std::string label;\n    label.app\n    geo::sc\n    return 0;\n}\n";

const DATABASE: &str = "[{\"directory\": \"..\", \"file\": \"src/main.cpp\", \"command\": \"clang++ -std=c++20 -Iinclude -c src/main.cpp -o build/main.o\"}]\n";

fn open() -> Option<Probe> {
    Probe::open(
        "clangd",
        &[
            ("include/shapes.hpp", HEADER),
            ("src/main.cpp", MAIN),
            ("build/compile_commands.json", DATABASE),
        ],
        "src/main.cpp",
    )
}

#[test]
fn an_auto_iterator_completes_the_element_members() {
    let Some(mut probe) = open() else {
        return;
    };
    let got = names(&probe.answered("it->is"));
    assert_eq!(got, ["is_square"]);
    let hit = &probe.at("it->is").hits[0];
    assert_eq!(hit.signature, "bool is_square() const");
}

#[test]
fn a_std_string_and_a_namespace_complete_from_clangd() {
    let Some(mut probe) = open() else {
        return;
    };
    let got = probe.until("label.app", "append");
    assert!(got.contains(&"append".to_string()), "{got:?}");
    let got = probe.until("geo::sc", "scale_all");
    assert_eq!(got, ["scale_all"]);
    assert!(names(&probe.at("geo::sc")).iter().all(|n| n != "Rect"));
}
