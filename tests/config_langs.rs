use ride_engine::{
    BufferSession, CaptureKind, CompletionContext, CompletionQuery, EngineConfig, ItemKind, Lang,
    QueryMode, engine_start, render_markdown,
};

const TOML: &str = "# manifest\n[package]\nname = \"demo\"\nversion = \"0.1.0\"\nedition = \"2024\"\n\n[dependencies]\nserde = { version = \"1\", features = [\"derive\"] }\n\n[profile.release]\nlto = true\nopt-level = 3\n\n[[bin]]\nname = \"demo\"\npath = \"src/main.rs\"\n";

const MAKE: &str = "CC ?= clang\nCFLAGS := -Wall -Iinclude\nSRC = $(wildcard src/*.c)\nOBJ := $(SRC:src/%.c=build/%.o)\n\nall: build/demo\n\nbuild/demo: $(OBJ)\n\t$(CC) $(CFLAGS) -o $@ $^\n\nifeq ($(DEBUG),1)\nCFLAGS += -g\nendif\n\n.PHONY: all clean\n\nclean:\n\trm -rf build\n";

const CMAKE: &str = "cmake_minimum_required(VERSION 3.20)\nproject(demo LANGUAGES C CXX)\n\nset(CMAKE_CXX_STANDARD 20)\noption(DEMO_TESTS \"Build tests\" ON)\n\nfunction(demo_add_warnings target)\n    target_compile_options(${target} PRIVATE -Wall)\nendfunction()\n\nadd_executable(demo src/main.cpp)\ndemo_add_warnings(demo)\nif(DEMO_TESTS)\n    add_library(demo_tests STATIC tests/main.cpp)\n    target_link_libraries(demo_tests PRIVATE demo)\nendif()\n";

fn spans(lang: Lang, src: &str) -> Vec<(CaptureKind, String)> {
    let (_, open) = BufferSession::open_lang(lang, src.to_string(), None).unwrap();
    open.highlights
        .iter()
        .map(|h| {
            (
                h.capture,
                src[h.start_byte as usize..h.end_byte as usize].to_string(),
            )
        })
        .collect()
}

fn has(spans: &[(CaptureKind, String)], kind: CaptureKind, text: &str) -> bool {
    spans.iter().any(|(k, t)| *k == kind && t == text)
}

fn outline(lang: Lang, src: &str) -> Vec<(String, ItemKind)> {
    let (_, open) = BufferSession::open_lang(lang, src.to_string(), None).unwrap();
    open.outline
        .unwrap()
        .into_iter()
        .map(|o| (o.name, o.kind))
        .collect()
}

fn engine() -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn names(engine: &ride_engine::Engine, session: u64, prefix: &str) -> Vec<(String, ItemKind)> {
    engine
        .query_completions(CompletionQuery {
            query_id: 1,
            session_id: session,
            prefix: prefix.into(),
            mode: QueryMode::Items,
            context: CompletionContext::Unknown,
            cursor_byte: 0,
            replace_start_byte: 0,
            current_crate: None,
            current_module: None,
            kind_filter: None,
            limit: 20,
        })
        .hits
        .into_iter()
        .map(|h| (h.name, h.item_kind))
        .collect()
}

#[test]
fn lang_from_file_names_and_fences() {
    assert_eq!(Lang::for_path(Some("/p/Cargo.toml")), Lang::Toml);
    assert_eq!(Lang::for_path(Some("/p/Makefile")), Lang::Make);
    assert_eq!(Lang::for_path(Some("/p/GNUmakefile")), Lang::Make);
    assert_eq!(Lang::for_path(Some("/p/rules.mk")), Lang::Make);
    assert_eq!(Lang::for_path(Some("/p/CMakeLists.txt")), Lang::Cmake);
    assert_eq!(Lang::for_path(Some("/p/cmake/Warnings.cmake")), Lang::Cmake);
    assert_eq!(Lang::for_path(Some("/p.d/notes.txt")), Lang::Rust);
    assert_eq!(Lang::for_path(Some("/p/main.c")), Lang::C);
    assert_eq!(Lang::for_fence("toml"), Some(Lang::Toml));
    assert_eq!(Lang::for_fence("makefile"), Some(Lang::Make));
    assert_eq!(Lang::for_fence("cmake"), Some(Lang::Cmake));
}

#[test]
fn toml_highlights_and_outline() {
    let s = spans(Lang::Toml, TOML);
    assert!(has(&s, CaptureKind::Comment, "# manifest"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "package"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "profile"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "release"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "bin"), "{s:?}");
    assert!(has(&s, CaptureKind::Property, "edition"), "{s:?}");
    assert!(has(&s, CaptureKind::Property, "features"), "{s:?}");
    assert!(has(&s, CaptureKind::String, "\"demo\""), "{s:?}");
    assert!(has(&s, CaptureKind::Constant, "true"), "{s:?}");
    assert!(has(&s, CaptureKind::Number, "3"), "{s:?}");
    assert!(has(&s, CaptureKind::Operator, "="), "{s:?}");
    let o = outline(Lang::Toml, TOML);
    let names: Vec<&str> = o.iter().map(|(n, _)| n.as_str()).collect();
    assert_eq!(
        names,
        vec!["package", "dependencies", "profile.release", "bin"],
        "{o:?}"
    );
    assert!(o.iter().all(|(_, k)| *k == ItemKind::Table));
}

#[test]
fn make_highlights_and_outline() {
    let s = spans(Lang::Make, MAKE);
    assert!(has(&s, CaptureKind::Variable, "CFLAGS"), "{s:?}");
    assert!(has(&s, CaptureKind::Variable, "SRC"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "wildcard"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "all"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "build/demo"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, ".PHONY"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "ifeq"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "endif"), "{s:?}");
    assert!(has(&s, CaptureKind::Constant, "$@"), "{s:?}");
    assert!(has(&s, CaptureKind::Operator, ":="), "{s:?}");
    let o = outline(Lang::Make, MAKE);
    assert!(o.contains(&("CC".to_string(), ItemKind::Static)), "{o:?}");
    assert!(o.contains(&("OBJ".to_string(), ItemKind::Static)), "{o:?}");
    assert!(o.contains(&("all".to_string(), ItemKind::Target)), "{o:?}");
    assert!(
        o.contains(&("build/demo".to_string(), ItemKind::Target)),
        "{o:?}"
    );
    assert!(
        o.contains(&("clean".to_string(), ItemKind::Target)),
        "{o:?}"
    );
}

#[test]
fn cmake_highlights_and_outline() {
    let s = spans(Lang::Cmake, CMAKE);
    assert!(
        has(&s, CaptureKind::Function, "cmake_minimum_required"),
        "{s:?}"
    );
    assert!(
        has(&s, CaptureKind::Function, "target_compile_options"),
        "{s:?}"
    );
    assert!(has(&s, CaptureKind::Function, "demo_add_warnings"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "function"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "endif"), "{s:?}");
    assert!(
        has(&s, CaptureKind::Constant, "CMAKE_CXX_STANDARD"),
        "{s:?}"
    );
    assert!(has(&s, CaptureKind::Variable, "target"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "demo"), "{s:?}");
    assert!(has(&s, CaptureKind::Constant, "PRIVATE"), "{s:?}");
    assert!(has(&s, CaptureKind::Constant, "ON"), "{s:?}");
    assert!(has(&s, CaptureKind::String, "\"Build tests\""), "{s:?}");
    let o = outline(Lang::Cmake, CMAKE);
    assert!(o.contains(&("demo".to_string(), ItemKind::Mod)), "{o:?}");
    assert!(
        o.contains(&("CMAKE_CXX_STANDARD".to_string(), ItemKind::Static)),
        "{o:?}"
    );
    assert!(
        o.contains(&("DEMO_TESTS".to_string(), ItemKind::Const)),
        "{o:?}"
    );
    assert!(
        o.contains(&("demo_add_warnings".to_string(), ItemKind::Fn)),
        "{o:?}"
    );
    assert!(o.contains(&("demo".to_string(), ItemKind::Target)), "{o:?}");
    assert!(
        o.contains(&("demo_tests".to_string(), ItemKind::Target)),
        "{o:?}"
    );
}

#[test]
fn completion_offers_keywords_and_buffer_items_without_the_catalog() {
    let engine = engine();
    let toml = engine
        .open_session("t".into(), Some("/p/Cargo.toml".into()), TOML.into(), None)
        .unwrap();
    assert_eq!(toml.lang, Lang::Toml);
    let hits = names(&engine, toml.session_id, "dep");
    assert!(
        hits.contains(&("dependencies".to_string(), ItemKind::Table)),
        "{hits:?}"
    );
    let hits = names(&engine, toml.session_id, "dev");
    assert!(
        hits.contains(&("dev-dependencies".to_string(), ItemKind::Keyword)),
        "{hits:?}"
    );
    let hits = names(&engine, toml.session_id, "edi");
    assert!(hits.iter().any(|(n, _)| n == "edition"), "{hits:?}");

    let make = engine
        .open_session("m".into(), Some("/p/Makefile".into()), MAKE.into(), None)
        .unwrap();
    let hits = names(&engine, make.session_id, "CF");
    assert!(
        hits.contains(&("CFLAGS".to_string(), ItemKind::Static)),
        "{hits:?}"
    );
    let hits = names(&engine, make.session_id, "pat");
    assert!(
        hits.contains(&("patsubst".to_string(), ItemKind::Keyword)),
        "{hits:?}"
    );
    let hits = names(&engine, make.session_id, "cle");
    assert!(
        hits.contains(&("clean".to_string(), ItemKind::Target)),
        "{hits:?}"
    );
    let at = MAKE.find("$(CFLAGS) -o").unwrap() + 2;
    let def = engine.find_definitions(make.session_id, at as u32);
    assert_eq!(def.symbol.unwrap().name, "CFLAGS");
    assert_eq!(def.hits.len(), 2, "{:?}", def.hits);

    let cmake = engine
        .open_session(
            "c".into(),
            Some("/p/CMakeLists.txt".into()),
            CMAKE.into(),
            None,
        )
        .unwrap();
    let hits = names(&engine, cmake.session_id, "target_");
    assert!(
        hits.iter()
            .any(|(n, k)| n == "target_link_libraries" && *k == ItemKind::Keyword),
        "{hits:?}"
    );
    let hits = names(&engine, cmake.session_id, "demo_");
    assert!(
        hits.contains(&("demo_add_warnings".to_string(), ItemKind::Fn)),
        "{hits:?}"
    );
    assert!(
        hits.contains(&("demo_tests".to_string(), ItemKind::Target)),
        "{hits:?}"
    );
    let at = CMAKE.find("PRIVATE demo)").unwrap() + "PRIVATE ".len() + 1;
    let def = engine.find_definitions(cmake.session_id, at as u32);
    assert_eq!(def.symbol.unwrap().name, "demo");
    assert!(
        def.hits.iter().any(|h| h.item_kind == ItemKind::Target),
        "{:?}",
        def.hits
    );
}

#[test]
fn fences_render_in_markdown() {
    let md = "```toml\n[package]\nname = \"x\"\n```\n\n```make\nall: build\n```\n\n```cmake\nproject(x)\n```\n";
    let (_, update) = BufferSession::open_lang(Lang::Markdown, md.to_string(), None).unwrap();
    let texts: Vec<(CaptureKind, &str)> = update
        .highlights
        .iter()
        .map(|h| (h.capture, &md[h.start_byte as usize..h.end_byte as usize]))
        .collect();
    assert!(texts.contains(&(CaptureKind::Type, "package")), "{texts:?}");
    assert!(texts.contains(&(CaptureKind::Function, "all")), "{texts:?}");
    assert!(
        texts.contains(&(CaptureKind::Function, "project")),
        "{texts:?}"
    );
    let html = render_markdown(md);
    assert!(html.contains("package"), "{html}");
}
