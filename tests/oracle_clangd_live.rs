mod oracle_support;

use oracle_support::{Probe, names};

const HEADER: &str = "#pragma once\n#include <string>\nnamespace geo {\nclass Rect {\npublic:\n    Rect(double w, double h) : w_(w), h_(h) {}\n    double area() const { return w_ * h_; }\n    bool is_square() const { return w_ == h_; }\n    double perimeter() const;\nprivate:\n    double w_;\n    double h_;\n};\nvoid scale_all(double factor);\n}\n";

const SHAPES: &str = "#include <shapes.hpp>\n\nnamespace geo {\ndouble Rect::perimeter() const { return 2 * (w_ + h_); }\n}\n";

const MAIN: &str = "#include <shapes.hpp>\n#include <string>\n#include <vector>\n\nint main() {\n    std::vector<geo::Rect> rects = {geo::Rect(1, 2)};\n    auto it = rects.begin();\n    it->is\n    std::string label;\n    label.app\n    geo::sc\n    return 0;\n}\n";

const DATABASE: &str = "[{\"directory\": \"..\", \"file\": \"src/main.cpp\", \"command\": \"clang++ -std=c++20 -Iinclude -c src/main.cpp -o build/main.o\"},{\"directory\": \"..\", \"file\": \"src/shapes.cpp\", \"command\": \"clang++ -std=c++20 -Iinclude -c src/shapes.cpp -o build/shapes.o\"}]\n";

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

#[test]
fn a_member_call_on_an_auto_iterator_goes_to_the_class() {
    let main = "#include <shapes.hpp>\n#include <vector>\n\nint main() {\n    std::vector<geo::Rect> rects = {geo::Rect(1, 2)};\n    auto it = rects.begin();\n    return it->is_square() ? 0 : 1;\n}\n";
    let Some(probe) = Probe::open(
        "clangd",
        &[
            ("include/shapes.hpp", HEADER),
            ("src/main.cpp", main),
            ("build/compile_commands.json", DATABASE),
        ],
        "src/main.cpp",
    ) else {
        return;
    };
    let hit = probe
        .definition_until("it->is", |h| {
            h.source_path
                .as_deref()
                .is_some_and(|p| p.ends_with("shapes.hpp"))
        })
        .expect("is_square resolves into shapes.hpp");
    assert_eq!(hit.signature, "bool is_square() const");
}

#[test]
fn a_declared_method_lists_its_declaration_and_its_definition() {
    let main = "#include <shapes.hpp>\n\nint main() {\n    geo::Rect r(1, 2);\n    return r.perimeter() > 0 ? 0 : 1;\n}\n";
    let Some(probe) = Probe::open(
        "clangd",
        &[
            ("include/shapes.hpp", HEADER),
            ("src/shapes.cpp", SHAPES),
            ("src/main.cpp", main),
            ("build/compile_commands.json", DATABASE),
        ],
        "src/main.cpp",
    ) else {
        return;
    };
    probe
        .definition_until("r.perim", |h| {
            h.source_path
                .as_deref()
                .is_some_and(|p| p.ends_with("shapes.cpp"))
        })
        .expect("the out-of-line definition once the index has the other file");
    let paths: Vec<String> = probe
        .engine
        .find_definitions(
            probe.session_id,
            main.find("r.perim").expect("anchor") as u32 + 3,
        )
        .hits
        .into_iter()
        .filter_map(|h| h.source_path)
        .collect();
    assert!(paths.iter().any(|p| p.ends_with("shapes.hpp")), "{paths:?}");
    assert!(
        !probe.root().join(".cache").exists(),
        "clangd wrote into the project"
    );
}

#[test]
fn type_info_names_the_type_behind_auto() {
    let Some(probe) = open() else {
        return;
    };
    let cursor = MAIN.find("auto it").expect("anchor") as u32 + 5;
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(120);
    let mut info = None;
    while info.is_none() && std::time::Instant::now() < deadline {
        info = probe.engine.type_info(probe.session_id, cursor);
        std::thread::sleep(std::time::Duration::from_millis(300));
    }
    let info = info.expect("type info");
    eprintln!("signature {:?}\nhtml {}", info.signature, info.html);
    let text = format!("{} {}", info.signature, info.html);
    assert!(text.contains("Rect"), "{text}");
}

#[test]
fn a_definition_under_the_caret_keeps_itself_next_to_its_declaration() {
    let main = "#include <shapes.hpp>\n\nint main() {\n    geo::Rect r(1, 2);\n    return r.perimeter() > 0 ? 0 : 1;\n}\n";
    let Some(probe) = Probe::open(
        "clangd",
        &[
            ("include/shapes.hpp", HEADER),
            ("src/shapes.cpp", SHAPES),
            ("src/main.cpp", main),
            ("build/compile_commands.json", DATABASE),
        ],
        "src/shapes.cpp",
    ) else {
        return;
    };
    let header = probe
        .definition_until("Rect::perim", |h| {
            h.source_path
                .as_deref()
                .is_some_and(|p| p.ends_with("shapes.hpp"))
        })
        .expect("the declaration in the header");
    assert!(
        header.signature.contains("perimeter"),
        "{}",
        header.signature
    );
    let cursor = SHAPES.find("Rect::perim").expect("anchor") as u32 + 8;
    let own = probe
        .engine
        .find_definitions(probe.session_id, cursor)
        .hits
        .into_iter()
        .find(|h| h.source_path.is_none())
        .expect("the definition under the caret");
    assert_eq!(
        own.byte_start,
        Some(SHAPES.find("perimeter").expect("name") as u32)
    );
}
