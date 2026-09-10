use std::path::{Path, PathBuf};

use ride_engine::{
    CompletionContext, CompletionQuery, EngineConfig, ItemKind, Lang, QueryMode, engine_start,
    include_dirs,
};

fn sample(name: &str) -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("samples")
        .join(name)
}

fn engine() -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn open(engine: &ride_engine::Engine, path: &Path) -> (u64, String, Lang) {
    let text = std::fs::read_to_string(path).unwrap();
    let opened = engine
        .open_session(
            "s".into(),
            Some(path.display().to_string()),
            text.clone(),
            None,
        )
        .unwrap();
    (opened.session_id, text, opened.lang)
}

fn members(engine: &ride_engine::Engine, id: u64, text: &str, after: &str) -> Vec<String> {
    let at = text.find(after).expect(after) + after.len();
    engine
        .query_completions(CompletionQuery {
            query_id: 1,
            session_id: id,
            prefix: String::new(),
            mode: QueryMode::BufferLocal,
            context: CompletionContext::Unknown,
            cursor_byte: at as u32,
            replace_start_byte: at as u32,
            current_crate: None,
            current_module: None,
            kind_filter: None,
            limit: 20,
        })
        .hits
        .into_iter()
        .map(|h| h.name)
        .collect()
}

fn definition(
    engine: &ride_engine::Engine,
    id: u64,
    text: &str,
    symbol: &str,
) -> (ItemKind, PathBuf) {
    let at = text.find(symbol).expect(symbol) + 1;
    let resp = engine.find_definitions(id, at as u32);
    let hit = resp
        .hits
        .first()
        .unwrap_or_else(|| panic!("no definition for {symbol}"));
    (
        hit.item_kind,
        hit.source_path
            .as_deref()
            .map(|p| Path::new(p).canonicalize().unwrap())
            .unwrap_or_default(),
    )
}

#[test]
fn c_demo_resolves_headers_members_and_macros() {
    let root = sample("c-demo");
    let engine = engine();
    let (id, text, lang) = open(&engine, &root.join("src/main.c"));
    assert_eq!(lang, Lang::C);
    assert_eq!(
        include_dirs(&root.join("src/main.c")),
        vec![root.join("include")]
    );
    assert_eq!(
        members(&engine, id, &text, "origin.x, origin."),
        vec!["x", "y"]
    );
    assert_eq!(
        members(&engine, id, &text, "    s->"),
        vec!["kind", "as", "label"]
    );
    assert_eq!(
        members(&engine, id, &text, "printf(\"%s\", out."),
        vec!["data", "len", "cap"]
    );
    let geometry = root.join("include/geometry.h").canonicalize().unwrap();
    assert_eq!(
        definition(&engine, id, &text, "rect_area(&box)"),
        (ItemKind::Fn, geometry.clone())
    );
    assert_eq!(
        definition(&engine, id, &text, "rect_t box"),
        (ItemKind::Type, geometry)
    );
    let config = root.join("include/config.h").canonicalize().unwrap();
    assert_eq!(
        definition(&engine, id, &text, "MAX_SHAPES];"),
        (ItemKind::Macro, config)
    );
    let util = root.join("src/util.h").canonicalize().unwrap();
    assert_eq!(
        definition(&engine, id, &text, "buffer_new(256)"),
        (ItemKind::Fn, util)
    );
}

#[test]
fn cpp_demo_resolves_classes_bases_this_and_sniffed_headers() {
    let root = sample("cpp-demo");
    let engine = engine();
    let (id, text, lang) = open(&engine, &root.join("src/main.cpp"));
    assert_eq!(lang, Lang::Cpp);
    let circle = members(&engine, id, &text, "circle.");
    assert!(
        circle.starts_with(&[
            "Circle".into(),
            "area".into(),
            "perimeter".into(),
            "scale".into(),
            "radius".into(),
            "radius_".into()
        ]),
        "{circle:?}"
    );
    assert!(
        circle.contains(&"describe".to_string()) && circle.contains(&"name_".to_string()),
        "{circle:?}"
    );
    let found = members(&engine, id, &text, "found->");
    assert!(
        found.contains(&"scale".to_string()) && found.contains(&"describe".to_string()),
        "{found:?}"
    );
    let shapes = root.join("include/shapes.hpp").canonicalize().unwrap();
    assert_eq!(
        definition(&engine, id, &text, "scale_all(rects"),
        (ItemKind::Fn, shapes.clone())
    );
    assert_eq!(
        definition(&engine, id, &text, "Circle circle"),
        (ItemKind::Class, shapes)
    );
    let registry = root.join("include/registry.h").canonicalize().unwrap();
    assert_eq!(
        definition(&engine, id, &text, "Registry registry"),
        (ItemKind::Class, registry)
    );
    let geo = members(&engine, id, &text, "    geo::");
    for expected in [
        "Circle",
        "Rect",
        "Registry",
        "Shape",
        "scale_all",
        "total_area",
    ] {
        assert!(
            geo.contains(&expected.to_string()),
            "{expected} missing in {geo:?}"
        );
    }
    let (id, text, _) = open(&engine, &root.join("src/registry.cpp"));
    let registry_members = members(&engine, id, &text, "void Registry::");
    assert_eq!(
        registry_members,
        vec!["add", "find", "size", "shapes_"],
        "{registry_members:?}"
    );

    let (id, text, lang) = open(&engine, &root.join("src/shapes.cpp"));
    assert_eq!(lang, Lang::Cpp);
    let this = members(
        &engine,
        id,
        &text,
        "void Circle::scale(Real factor) {\n    this->",
    );
    for expected in ["radius_", "radius", "area", "describe", "name_"] {
        assert!(
            this.contains(&expected.to_string()),
            "{expected} missing in {this:?}"
        );
    }
    assert!(!this.contains(&"width_".to_string()), "{this:?}");
    let base = members(&engine, id, &text, "out << this->");
    for expected in ["name", "describe", "name_", "area"] {
        assert!(
            base.contains(&expected.to_string()),
            "{expected} missing in {base:?}"
        );
    }
    assert!(!base.contains(&"radius_".to_string()), "{base:?}");

    let (_, _, lang) = open(&engine, &root.join("include/registry.h"));
    assert_eq!(lang, Lang::Cpp);
}
