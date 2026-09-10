use ride_engine::{
    BufferSession, CaptureKind, CompletionQuery, EngineConfig, ItemKind, Lang, QueryMode,
    engine_start, render_markdown,
};

const C_SRC: &str = "#include <stdio.h>\n#define LIMIT 10\n#define SQUARE(x) ((x) * (x))\n\ntypedef struct point { int x; int y; } point_t;\nenum color { RED, GREEN };\nstatic int counter = 0;\nint add(int a, int b);\n\nint add(int a, int b) {\n    /* sum */\n    return a + b;\n}\n\nint main(void) {\n    point_t p = { 1, 2 };\n    int total = add(p.x, LIMIT);\n    printf(\"%d\\n\", total);\n    return 0;\n}\n";

const CPP_SRC: &str = "#include <vector>\nnamespace geo {\nclass Shape {\npublic:\n    virtual ~Shape() = default;\n    virtual double area() const = 0;\n};\nstruct Circle : Shape {\n    double r;\n    double area() const override;\n};\ndouble Circle::area() const { return 3.14 * r * r; }\ntemplate <typename T>\nT twice(T v) { return v + v; }\nusing Num = double;\n}\nint main() {\n    auto c = geo::Circle{};\n    std::vector<int> xs;\n    return static_cast<int>(geo::twice(c.area()));\n}\n";

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

#[test]
fn c_highlights_keywords_types_functions_and_macros() {
    let s = spans(Lang::C, C_SRC);
    assert!(has(&s, CaptureKind::Keyword, "#include"), "{s:?}");
    assert!(has(&s, CaptureKind::String, "<stdio.h>"), "{s:?}");
    assert!(has(&s, CaptureKind::Macro, "LIMIT"), "{s:?}");
    assert!(has(&s, CaptureKind::Macro, "SQUARE"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "typedef"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "int"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "point_t"), "{s:?}");
    assert!(has(&s, CaptureKind::Constant, "RED"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "add"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "printf"), "{s:?}");
    assert!(has(&s, CaptureKind::Property, "x"), "{s:?}");
    assert!(has(&s, CaptureKind::Number, "0"), "{s:?}");
    assert!(has(&s, CaptureKind::Comment, "/* sum */"), "{s:?}");
    assert!(has(&s, CaptureKind::Variable, "total"), "{s:?}");
}

#[test]
fn cpp_highlights_classes_namespaces_and_templates() {
    let s = spans(Lang::Cpp, CPP_SRC);
    assert!(has(&s, CaptureKind::Keyword, "namespace"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "class"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "virtual"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "override"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "template"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "using"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "Shape"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "auto"), "{s:?}");
    assert!(has(&s, CaptureKind::Type, "geo"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "area"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "twice"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "Shape"), "{s:?}");
    assert!(has(&s, CaptureKind::Punctuation, "::"), "{s:?}");
}

#[test]
fn c_outline_lists_items() {
    let (_, open) = BufferSession::open_lang(Lang::C, C_SRC.to_string(), None).unwrap();
    let outline = open.outline.unwrap();
    let items: Vec<(&str, ItemKind)> = outline.iter().map(|o| (o.name.as_str(), o.kind)).collect();
    assert!(items.contains(&("LIMIT", ItemKind::Macro)), "{items:?}");
    assert!(items.contains(&("SQUARE", ItemKind::Macro)), "{items:?}");
    assert!(items.contains(&("point", ItemKind::Struct)), "{items:?}");
    assert!(items.contains(&("point_t", ItemKind::Type)), "{items:?}");
    assert!(items.contains(&("color", ItemKind::Enum)), "{items:?}");
    assert!(items.contains(&("counter", ItemKind::Static)), "{items:?}");
    assert!(items.contains(&("main", ItemKind::Fn)), "{items:?}");
    assert_eq!(
        items.iter().filter(|i| i.0 == "add").count(),
        2,
        "{items:?}"
    );
    assert!(!items.iter().any(|i| i.0 == "total"), "{items:?}");
    assert!(!items.iter().any(|i| i.0 == "x"), "{items:?}");
}

#[test]
fn cpp_outline_lists_classes_methods_and_namespaces() {
    let (_, open) = BufferSession::open_lang(Lang::Cpp, CPP_SRC.to_string(), None).unwrap();
    let outline = open.outline.unwrap();
    let items: Vec<(&str, ItemKind)> = outline.iter().map(|o| (o.name.as_str(), o.kind)).collect();
    assert!(items.contains(&("geo", ItemKind::Namespace)), "{items:?}");
    assert!(items.contains(&("Shape", ItemKind::Class)), "{items:?}");
    assert!(items.contains(&("Circle", ItemKind::Struct)), "{items:?}");
    assert!(items.contains(&("twice", ItemKind::Fn)), "{items:?}");
    assert!(items.contains(&("Num", ItemKind::Type)), "{items:?}");
    assert!(items.contains(&("main", ItemKind::Fn)), "{items:?}");
    assert_eq!(
        items
            .iter()
            .filter(|i| *i == &("area", ItemKind::Method))
            .count(),
        3,
        "{items:?}"
    );
    assert!(items.contains(&("~Shape", ItemKind::Method)), "{items:?}");
    assert!(!items.iter().any(|i| i.0 == "r"), "{items:?}");
}

#[test]
fn c_parse_errors_are_reported() {
    let (_, open) = BufferSession::open_lang(Lang::C, "int f( {".to_string(), None).unwrap();
    assert!(!open.errors.is_empty());
    let (_, ok) = BufferSession::open_lang(Lang::C, C_SRC.to_string(), None).unwrap();
    assert!(ok.errors.is_empty(), "{:?}", ok.errors);
    let (_, ok) = BufferSession::open_lang(Lang::Cpp, CPP_SRC.to_string(), None).unwrap();
    assert!(ok.errors.is_empty(), "{:?}", ok.errors);
}

fn engine() -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn query(session_id: u64, prefix: &str, mode: QueryMode) -> CompletionQuery {
    CompletionQuery {
        query_id: 1,
        session_id,
        prefix: prefix.into(),
        mode,
        context: ride_engine::CompletionContext::Unknown,
        cursor_byte: 0,
        replace_start_byte: 0,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    }
}

#[test]
fn engine_picks_c_and_cpp_from_path_and_completes_locals_and_keywords() {
    let engine = engine();
    let c = engine
        .open_session("c".into(), Some("/tmp/x.c".into()), C_SRC.into(), None)
        .unwrap();
    let resp = engine.query_completions(query(c.session_id, "cou", QueryMode::BufferLocal));
    assert!(resp.hits.iter().any(|h| h.name == "counter"), "{resp:?}");
    let resp = engine.query_completions(query(c.session_id, "type", QueryMode::Items));
    assert!(
        resp.hits
            .iter()
            .any(|h| h.name == "typedef" && h.item_kind == ItemKind::Keyword),
        "{resp:?}"
    );
    assert!(!resp.hits.iter().any(|h| h.name == "namespace"), "{resp:?}");
    let cpp = engine
        .open_session("h".into(), Some("/tmp/x.hpp".into()), CPP_SRC.into(), None)
        .unwrap();
    let resp = engine.query_completions(query(cpp.session_id, "name", QueryMode::Items));
    assert!(resp.hits.iter().any(|h| h.name == "namespace"), "{resp:?}");
    assert!(
        cpp.update
            .outline
            .unwrap()
            .iter()
            .any(|o| o.kind == ItemKind::Class)
    );
    let h = engine
        .open_session("h".into(), Some("/tmp/x.h".into()), C_SRC.into(), None)
        .unwrap();
    let resp = engine.query_completions(query(h.session_id, "clas", QueryMode::Items));
    assert!(!resp.hits.iter().any(|h| h.name == "class"), "{resp:?}");
}

#[test]
fn cpp_definitions_resolve_within_the_buffer() {
    let engine = engine();
    let open = engine
        .open_session("c".into(), Some("/tmp/x.cc".into()), CPP_SRC.into(), None)
        .unwrap();
    let at = CPP_SRC.find("geo::twice").unwrap() + "geo::".len() + 1;
    let resp = engine.find_definitions(open.session_id, at as u32);
    let symbol = resp.symbol.expect("symbol");
    assert_eq!(symbol.name, "twice");
    assert_eq!(symbol.qualifier.as_deref(), Some("geo"));
    assert_eq!(resp.hits.len(), 1, "{:?}", resp.hits);
    assert_eq!(resp.hits[0].item_kind, ItemKind::Fn);
    let at = CPP_SRC.find("c.area()").unwrap() + 3;
    let resp = engine.find_definitions(open.session_id, at as u32);
    assert_eq!(resp.symbol.unwrap().name, "area");
    assert_eq!(resp.hits.len(), 3, "{:?}", resp.hits);
}

#[test]
fn c_and_cpp_fences_highlight_in_markdown_editor_and_preview() {
    let md = "# Doc\n\n```c\nint main(void) { return 0; }\n```\n\n```cpp\nnamespace a {}\n```\n\n```rust\nfn f() {}\n```\n";
    let (_, update) = BufferSession::open_lang(Lang::Markdown, md.to_string(), None).unwrap();
    let s: Vec<(CaptureKind, String)> = update
        .highlights
        .iter()
        .map(|h| {
            (
                h.capture,
                md[h.start_byte as usize..h.end_byte as usize].to_string(),
            )
        })
        .collect();
    assert!(has(&s, CaptureKind::Type, "int"), "{s:?}");
    assert!(has(&s, CaptureKind::Function, "main"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "namespace"), "{s:?}");
    assert!(has(&s, CaptureKind::Keyword, "fn"), "{s:?}");
    let html = render_markdown(md);
    assert!(
        html.contains("<span class=\"tk-keyword\">return</span>"),
        "{html}"
    );
    assert!(
        html.contains("<span class=\"tk-keyword\">namespace</span>"),
        "{html}"
    );
    assert!(
        html.contains("<span class=\"tk-keyword\">fn</span>"),
        "{html}"
    );
}

#[test]
fn lang_for_path_and_fence() {
    assert_eq!(Lang::for_path(Some("a/b.c")), Lang::C);
    assert_eq!(Lang::for_path(Some("a/b.H")), Lang::C);
    assert_eq!(Lang::for_path(Some("a/b.cpp")), Lang::Cpp);
    assert_eq!(Lang::for_path(Some("a/b.hpp")), Lang::Cpp);
    assert_eq!(Lang::for_path(Some("a/b.cxx")), Lang::Cpp);
    assert_eq!(Lang::for_path(Some("a/b.rs")), Lang::Rust);
    assert_eq!(Lang::for_path(None), Lang::Rust);
    assert_eq!(Lang::for_fence("c"), Some(Lang::C));
    assert_eq!(Lang::for_fence("c++"), Some(Lang::Cpp));
    assert_eq!(Lang::for_fence("cpp,ignore"), Some(Lang::Cpp));
    assert_eq!(Lang::for_fence("text"), None);
}
