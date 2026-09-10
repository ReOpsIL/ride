use std::fs;

use ride_engine::{
    CompletionContext, CompletionQuery, CompletionSiteKind, EngineConfig, ItemKind, QueryMode,
    engine_start,
};

const GEO_HPP: &str = "#pragma once\nnamespace geo {\nusing Real = double;\nconstexpr Real PI = 3.14;\nclass Shape {\npublic:\n    virtual Real area() const = 0;\n    static int count();\n    enum Kind { Round, Square };\n};\nnamespace detail {\nint helper();\nstruct Node { int value; };\n}\ninline namespace v2 {\nReal scale(Real r);\n}\nReal total(const Shape &s);\n}\nnamespace alias_ns = geo::detail;\nusing Fig = geo::Shape;\nenum class Color { Red, Green };\n";

const MAIN_CPP: &str = "#include \"geo.hpp\"\nnamespace local { struct Thing { int a; }; int make(); }\nint main() {\n    geo:: ;\n    geo::S ;\n    geo::Shape:: ;\n    geo::detail:: ;\n    alias_ns:: ;\n    Fig:: ;\n    Color:: ;\n    geo::Shape::Kind:: ;\n    local:: ;\n    return 0;\n}\n";

fn engine() -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn scoped(
    engine: &ride_engine::Engine,
    session: u64,
    after: &str,
) -> (CompletionSiteKind, Vec<(String, ItemKind)>) {
    let at = MAIN_CPP.find(after).expect(after) + after.len();
    let resp = engine.query_completions(CompletionQuery {
        query_id: 1,
        session_id: session,
        prefix: String::new(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at as u32,
        replace_start_byte: at as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    });
    (
        resp.site,
        resp.hits
            .into_iter()
            .map(|h| (h.name, h.item_kind))
            .collect(),
    )
}

fn names(hits: &[(String, ItemKind)]) -> Vec<&str> {
    hits.iter().map(|(n, _)| n.as_str()).collect()
}

fn open() -> (tempfile::TempDir, std::sync::Arc<ride_engine::Engine>, u64) {
    let dir = tempfile::tempdir().unwrap();
    fs::write(dir.path().join("geo.hpp"), GEO_HPP).unwrap();
    fs::write(dir.path().join("main.cpp"), MAIN_CPP).unwrap();
    let engine = engine();
    let id = engine
        .open_session(
            "m".into(),
            Some(dir.path().join("main.cpp").display().to_string()),
            MAIN_CPP.into(),
            None,
        )
        .unwrap()
        .session_id;
    (dir, engine, id)
}

#[test]
fn namespace_paths_list_direct_members_in_declaration_order() {
    let (_dir, engine, id) = open();
    let (site, hits) = scoped(&engine, id, "    geo::");
    assert_eq!(site, CompletionSiteKind::ScopedPath);
    assert_eq!(
        names(&hits),
        vec!["Real", "PI", "Shape", "detail", "scale", "total"],
        "{hits:?}"
    );
    assert!(hits.contains(&("Shape".to_string(), ItemKind::Class)));
    assert!(hits.contains(&("detail".to_string(), ItemKind::Namespace)));
    assert!(hits.contains(&("scale".to_string(), ItemKind::Fn)));
    let (_, nested) = scoped(&engine, id, "geo::detail::");
    assert_eq!(names(&nested), vec!["helper", "Node"], "{nested:?}");
    let (_, filtered) = scoped(&engine, id, "geo::S");
    assert_eq!(names(&filtered), vec!["Shape", "scale"], "{filtered:?}");
    let (_, local) = scoped(&engine, id, "    local::");
    assert_eq!(names(&local), vec!["Thing", "make"], "{local:?}");
}

#[test]
fn class_paths_list_members_and_enums_list_their_variants() {
    let (_dir, engine, id) = open();
    let (_, shape) = scoped(&engine, id, "geo::Shape::");
    assert_eq!(names(&shape), vec!["area", "count", "Kind"], "{shape:?}");
    assert!(shape.contains(&("count".to_string(), ItemKind::Method)));
    assert!(shape.contains(&("Kind".to_string(), ItemKind::Enum)));
    let (_, kind) = scoped(&engine, id, "geo::Shape::Kind::");
    assert_eq!(names(&kind), vec!["Round", "Square"], "{kind:?}");
    let (_, color) = scoped(&engine, id, "    Color::");
    assert_eq!(
        color,
        vec![
            ("Red".to_string(), ItemKind::Variant),
            ("Green".to_string(), ItemKind::Variant)
        ]
    );
}

#[test]
fn namespace_and_type_aliases_are_followed() {
    let (_dir, engine, id) = open();
    let (_, via_ns_alias) = scoped(&engine, id, "    alias_ns::");
    assert_eq!(
        names(&via_ns_alias),
        vec!["helper", "Node"],
        "{via_ns_alias:?}"
    );
    let (_, via_type_alias) = scoped(&engine, id, "    Fig::");
    assert_eq!(
        names(&via_type_alias),
        vec!["area", "count", "Kind"],
        "{via_type_alias:?}"
    );
}
