use std::collections::HashSet;

use ride_engine::{BufferSession, Context, Lang, engine_start, select, sheet, validate};

fn context(lang: Lang, src: &str) -> Context {
    let at = src.find('|').expect("caret");
    let text = src.replacen('|', "", 1);
    let (session, _) = BufferSession::open_lang(lang, text, None).unwrap();
    session.context_at(at as u32)
}

#[test]
fn every_sheet_parses() {
    for lang in [
        Lang::Rust,
        Lang::C,
        Lang::Cpp,
        Lang::Make,
        Lang::Cmake,
        Lang::Toml,
    ] {
        let sheet = validate(lang).unwrap_or_else(|e| panic!("{lang:?}: {e}"));
        assert!(!sheet.sections.is_empty(), "{lang:?} has no sections");
        for section in &sheet.sections {
            assert!(!section.entries.is_empty(), "{}: no entries", section.file);
            let mut names = HashSet::new();
            for entry in &section.entries {
                assert!(
                    names.insert(entry.name.as_str()),
                    "{}: duplicate name {}",
                    section.file,
                    entry.name
                );
            }
        }
    }
}

#[test]
fn rust_contexts() {
    assert_eq!(context(Lang::Rust, "fn main() {}\n|"), Context::Item);
    assert_eq!(context(Lang::Rust, "fn main() {}\nst|"), Context::Item);
    assert_eq!(
        context(Lang::Rust, "fn main() {\n    |\n}"),
        Context::Statement
    );
    assert_eq!(
        context(Lang::Rust, "fn main() {\n    le|\n}"),
        Context::Statement
    );
    assert_eq!(
        context(Lang::Rust, "fn main() {\n    let x = |\n}"),
        Context::Expression
    );
    assert_eq!(
        context(Lang::Rust, "fn main() {\n    let x: |\n}"),
        Context::Type
    );
    assert_eq!(
        context(Lang::Rust, "fn main() {\n    let |\n}"),
        Context::Pattern
    );
    assert_eq!(context(Lang::Rust, "fn f(x: |) {}"), Context::Type);
    assert_eq!(context(Lang::Rust, "fn f() -> |"), Context::Type);
    assert_eq!(context(Lang::Rust, "struct S {\n    |\n}"), Context::Fields);
    assert_eq!(context(Lang::Rust, "impl S {\n    |\n}"), Context::Body);
    assert_eq!(
        context(Lang::Rust, "impl S {\n    pub f|\n}"),
        Context::Body
    );
    assert_eq!(context(Lang::Rust, "mod m {\n    |\n}"), Context::Item);
    assert_eq!(context(Lang::Rust, "#[|]\nfn f() {}"), Context::Attribute);
    assert_eq!(context(Lang::Rust, "use std::|"), Context::Use);
    assert_eq!(
        context(
            Lang::Rust,
            "fn f(x: Option<u8>) {\n    match x {\n        |\n    }\n}"
        ),
        Context::Case
    );
    assert_eq!(
        context(
            Lang::Rust,
            "fn f(x: Option<u8>) {\n    match x {\n        Some(v) => |\n    }\n}"
        ),
        Context::Expression
    );
    assert_eq!(
        context(Lang::Rust, "fn f() {\n    if x {\n        |\n    }\n}"),
        Context::Statement
    );
}

#[test]
fn c_contexts() {
    assert_eq!(context(Lang::C, "#include <stdio.h>\n|"), Context::Item);
    assert_eq!(context(Lang::C, "#inc|"), Context::Preprocessor);
    assert_eq!(context(Lang::C, "#define X |"), Context::Preprocessor);
    assert_eq!(
        context(Lang::C, "int main(void) {\n    |\n}"),
        Context::Statement
    );
    assert_eq!(
        context(Lang::C, "int main(void) {\n    int x = |;\n}"),
        Context::Expression
    );
    assert_eq!(
        context(Lang::C, "int main(void) {\n    if (x) |\n}"),
        Context::Statement
    );
    assert_eq!(context(Lang::C, "struct s {\n    |\n};"), Context::Fields);
    assert_eq!(
        context(Lang::C, "int main(void) {\n    fo|\n}"),
        Context::Statement
    );
    assert_eq!(
        context(Lang::C, "int main(void) {\n    struct s|\n}"),
        Context::Type
    );
    assert_eq!(context(Lang::C, "int f(|);"), Context::Type);
    assert_eq!(context(Lang::Cpp, "class A {\n    |\n};"), Context::Fields);
    assert_eq!(context(Lang::Cpp, "namespace n {\n    |\n}"), Context::Item);
    assert_eq!(context(Lang::Cpp, "template <|"), Context::Type);
    assert_eq!(
        context(
            Lang::Cpp,
            "int main() {\n    auto f = [](int a) {\n        |\n    };\n}"
        ),
        Context::Statement
    );
}

#[test]
fn make_contexts() {
    assert_eq!(context(Lang::Make, "|"), Context::Item);
    assert_eq!(context(Lang::Make, "all: main.o\n|"), Context::Item);
    assert_eq!(context(Lang::Make, ".PH|"), Context::Item);
    assert_eq!(context(Lang::Make, "all: main.o\n\t|"), Context::Recipe);
    assert_eq!(
        context(Lang::Make, "all: main.o\n\t$(CC) $(|"),
        Context::Function
    );
    assert_eq!(context(Lang::Make, "SRCS := $(wild|"), Context::Function);
    assert_eq!(context(Lang::Make, "SRCS := |"), Context::Value);
    assert_eq!(context(Lang::Make, "all: |"), Context::Value);
    assert_eq!(
        context(Lang::Make, "CFLAGS += -Wall $(X) |"),
        Context::Value
    );
}

#[test]
fn lookup_ranks_context_sections_first_and_narrows_by_prefix() {
    let sheet = sheet(Lang::Rust).unwrap();
    let all = select(sheet, Context::Statement, "", false);
    assert!(all.iter().all(|s| s.matched));
    assert!(all.iter().any(|s| s.section.title == "Control flow"));
    let narrowed = select(sheet, Context::Statement, "ma", false);
    let control = narrowed
        .iter()
        .find(|s| s.section.title == "Control flow")
        .expect("control flow section");
    assert!(control.matched);
    assert!(control.entries.iter().any(|e| e.name == "match"));
    assert!(control.entries.iter().all(|e| e.matches("ma")));
    let by_name = select(sheet, Context::Expression, "it", false);
    assert!(by_name[0].by_name, "{}", by_name[0].section.title);
    assert!(by_name[0].section.title.starts_with("Iterators"));
    let none = select(sheet, Context::Statement, "zzz", false);
    assert!(none.is_empty());
    let browse = select(sheet, Context::Attribute, "", true);
    assert_eq!(browse.len(), sheet.sections.len());
    let explicit_first = all
        .iter()
        .map(|s| s.section.contexts.is_empty())
        .collect::<Vec<_>>();
    assert!(explicit_first.windows(2).all(|w| w[0] <= w[1]));
}

#[test]
fn engine_cheat_sheet_uses_site_prefix_and_indent() {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(ride_engine::EngineConfig {
        index_dir: dir.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    let src = "fn main() {\n    ma\n}\n";
    let open = engine
        .open_session("t".into(), Some("main.rs".into()), src.into(), None)
        .unwrap();
    let at = src.find("ma\n").unwrap() + 2;
    let resp = engine.cheat_sheet(open.session_id, at as u32, false);
    assert_eq!(resp.context, "statement");
    assert_eq!(resp.prefix, "ma");
    assert_eq!(resp.replace_start_byte as usize, at - 2);
    assert!(resp.sections[0].matched);
    let entry = resp
        .sections
        .iter()
        .flat_map(|s| s.entries.iter())
        .find(|e| e.name == "match")
        .expect("match entry");
    assert!(
        entry
            .snippet
            .lines()
            .nth(1)
            .unwrap()
            .starts_with("        ")
    );
    let member = "fn main() {\n    let v = vec![1];\n    v.it\n}\n";
    let open = engine
        .open_session("t".into(), Some("main.rs".into()), member.into(), None)
        .unwrap();
    let at = member.find("v.it").unwrap() + 4;
    let resp = engine.cheat_sheet(open.session_id, at as u32, false);
    assert_eq!(resp.context, "expression");
    let iter = resp
        .sections
        .iter()
        .flat_map(|s| s.entries.iter())
        .find(|e| e.name == "iter")
        .expect("iter entry");
    assert_eq!(iter.snippet, "iter()$0");
    let comment = "// ma\n";
    let open = engine
        .open_session("t".into(), Some("main.rs".into()), comment.into(), None)
        .unwrap();
    let resp = engine.cheat_sheet(open.session_id, 5, false);
    assert!(resp.sections.is_empty());
}

#[test]
fn cmake_contexts() {
    assert_eq!(context(Lang::Cmake, "|"), Context::Statement);
    assert_eq!(context(Lang::Cmake, "add_executable(|"), Context::Argument);
    assert_eq!(
        context(Lang::Cmake, "if(FOO)\n  |\nendif()\n"),
        Context::Statement
    );
    assert_eq!(
        context(Lang::Cmake, "function(foo)\n  se|\nendfunction()\n"),
        Context::Statement
    );
    assert_eq!(
        context(Lang::Cmake, "target_link_libraries(demo PRIVATE |)"),
        Context::Argument
    );
}

#[test]
fn cmake_argument_ranks_find_and_link_first() {
    let ctx = context(Lang::Cmake, "target_link_libraries(|");
    assert_eq!(ctx, Context::Argument);
    let sheet = sheet(Lang::Cmake).unwrap();
    let ranked = select(sheet, ctx, "", false);
    assert_eq!(ranked[0].section.file, "find-and-link");
    assert!(
        ranked[0]
            .entries
            .iter()
            .any(|e| e.name == "target_link_libraries"),
        "{:?}",
        ranked[0]
            .entries
            .iter()
            .map(|e| e.name.as_str())
            .collect::<Vec<_>>()
    );
}

#[test]
fn rust_match_arm_offers_match() {
    let ctx = context(
        Lang::Rust,
        "fn f(x: Option<u8>) {\n    match x {\n        |\n    }\n}",
    );
    assert_eq!(ctx, Context::Case);
    let names: Vec<_> = select(sheet(Lang::Rust).unwrap(), ctx, "", false)
        .iter()
        .flat_map(|s| s.entries.iter().map(|e| e.name.as_str()))
        .collect();
    assert!(names.contains(&"match"), "{names:?}");
}

#[test]
fn c_switch_body_offers_case_and_default() {
    let ctx = context(
        Lang::C,
        "int main(void) {\n    switch (x) {\n        |\n    }\n}",
    );
    assert_eq!(ctx, Context::Case);
    let names: Vec<_> = select(sheet(Lang::C).unwrap(), ctx, "", false)
        .iter()
        .flat_map(|s| s.entries.iter().map(|e| e.name.as_str()))
        .collect();
    assert!(names.contains(&"case"), "{names:?}");
    assert!(names.contains(&"default"), "{names:?}");
}

#[test]
fn toml_contexts() {
    assert_eq!(context(Lang::Toml, "|"), Context::Table);
    assert_eq!(context(Lang::Toml, "[|"), Context::Table);
    assert_eq!(context(Lang::Toml, "[dep|"), Context::Table);
    assert_eq!(context(Lang::Toml, "[dependencies]\n|"), Context::Key);
    assert_eq!(context(Lang::Toml, "[dependencies]\nser|"), Context::Key);
    assert_eq!(context(Lang::Toml, "[package]\nname|"), Context::Key);
    assert_eq!(
        context(Lang::Toml, "serde = { version = \"1\", |}"),
        Context::Key
    );
}

#[test]
fn toml_dependencies_offer_crate_entries() {
    let ctx = context(Lang::Toml, "[dependencies]\n|");
    assert_eq!(ctx, Context::Key);
    let sheet = sheet(Lang::Toml).unwrap();
    let ranked = select(sheet, ctx, "", false);
    let deps = ranked
        .iter()
        .find(|s| s.section.file == "cargo-dependencies")
        .expect("cargo-dependencies");
    assert!(
        deps.entries.iter().any(|e| e.name == "crate"),
        "{:?}",
        deps.entries
            .iter()
            .map(|e| e.name.as_str())
            .collect::<Vec<_>>()
    );
}
