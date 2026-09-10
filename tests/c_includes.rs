use std::fs;
use std::path::Path;

use ride_engine::{
    CompletionContext, CompletionQuery, EngineConfig, ItemKind, Lang, QueryMode, engine_start,
    include_dirs,
};

const SHAPES_H: &str = "#pragma once\n#include \"limits.h\"\nstruct shape { int sides; double area; };\ntypedef struct shape shape_t;\nint shape_sides(const shape_t *s);\n";
const LIMITS_H: &str = "#define MAX_SIDES 12\n";
const MAIN_C: &str = "#include \"shapes.h\"\n#include <ext.h>\nint main(void) {\n    shape_t s;\n    s.sides = shape_sides(&s) + ext_value();\n    return MAX_SIDES;\n}\n";
const EXT_H: &str = "int ext_value(void);\n";

fn engine() -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn query(session_id: u64, prefix: &str, at: usize) -> CompletionQuery {
    let at = at + prefix.len();
    CompletionQuery {
        query_id: 1,
        session_id,
        prefix: prefix.into(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at as u32,
        replace_start_byte: at as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    }
}

fn project() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    fs::create_dir_all(root.join("include")).unwrap();
    fs::create_dir_all(root.join("build")).unwrap();
    fs::write(root.join("shapes.h"), SHAPES_H).unwrap();
    fs::write(root.join("limits.h"), LIMITS_H).unwrap();
    fs::write(root.join("include/ext.h"), EXT_H).unwrap();
    fs::write(root.join("main.c"), MAIN_C).unwrap();
    fs::write(root.join("other.cpp"), "int cpp_only();\n").unwrap();
    let db = format!(
        "[{{\"directory\": \"{0}\", \"file\": \"main.c\", \"command\": \"cc -std=c11 -Iinclude -isystem /opt/sys -c main.c -o main.o\"}},\n {{\"directory\": \"{0}\", \"file\": \"other.cpp\", \"arguments\": [\"c++\", \"-std=c++20\", \"-I\", \"cpp_inc\", \"-c\", \"other.cpp\"]}}]",
        root.display()
    );
    fs::write(root.join("build/compile_commands.json"), db).unwrap();
    dir
}

fn same_file(a: &str, b: &Path) -> bool {
    Path::new(a).canonicalize().ok() == b.canonicalize().ok()
}

#[test]
fn include_dirs_come_from_the_compile_database_entry_of_the_same_language() {
    let dir = project();
    let root = dir.path().canonicalize().unwrap();
    let root = root.as_path();
    let dirs = include_dirs(&root.join("main.c"));
    assert_eq!(
        dirs,
        vec![root.join("include"), Path::new("/opt/sys").to_path_buf()],
        "{dirs:?}"
    );
    let header = include_dirs(&root.join("shapes.h"));
    assert_eq!(
        header,
        vec![root.join("include"), Path::new("/opt/sys").to_path_buf()]
    );
    let cpp = include_dirs(&root.join("other.cpp"));
    assert_eq!(cpp, vec![root.join("cpp_inc")]);
}

#[test]
fn definitions_and_completions_reach_included_headers() {
    let dir = project();
    let root = dir.path();
    let engine = engine();
    let open = engine
        .open_session(
            "c".into(),
            Some(root.join("main.c").display().to_string()),
            MAIN_C.into(),
            None,
        )
        .unwrap();
    assert_eq!(open.lang, Lang::C);
    let id = open.session_id;

    let at = MAIN_C.find("shape_sides(&s)").unwrap() + 2;
    let resp = engine.find_definitions(id, at as u32);
    assert_eq!(resp.hits.len(), 1, "{:?}", resp.hits);
    assert!(same_file(
        resp.hits[0].source_path.as_deref().unwrap(),
        &root.join("shapes.h")
    ));
    assert_eq!(resp.hits[0].item_kind, ItemKind::Fn);

    let at = MAIN_C.find("MAX_SIDES").unwrap() + 1;
    let resp = engine.find_definitions(id, at as u32);
    assert_eq!(resp.hits.len(), 1, "{:?}", resp.hits);
    assert!(same_file(
        resp.hits[0].source_path.as_deref().unwrap(),
        &root.join("limits.h")
    ));
    assert_eq!(resp.hits[0].item_kind, ItemKind::Macro);

    let at = MAIN_C.find("ext_value").unwrap() + 1;
    let resp = engine.find_definitions(id, at as u32);
    assert_eq!(resp.hits.len(), 1, "{:?}", resp.hits);
    assert!(same_file(
        resp.hits[0].source_path.as_deref().unwrap(),
        &root.join("include/ext.h")
    ));

    let at = MAIN_C.find("shape_sides(&s)").unwrap();
    let resp = engine.query_completions(query(id, "shape_", at));
    let hit = resp
        .hits
        .iter()
        .find(|h| h.name == "shape_sides")
        .expect("header completion");
    assert!(same_file(
        hit.source_path.as_deref().unwrap(),
        &root.join("shapes.h")
    ));
    assert!(
        resp.hits
            .iter()
            .any(|h| h.name == "shape_t" && h.item_kind == ItemKind::Type)
    );

    let at = MAIN_C.find("s.sides").unwrap() + 2;
    let resp = engine.query_completions(query(id, "", at));
    let members: Vec<_> = resp.hits.iter().map(|h| h.name.as_str()).collect();
    assert_eq!(members, vec!["sides", "area"], "{members:?}");
    assert!(same_file(
        resp.hits[0].source_path.as_deref().unwrap(),
        &root.join("shapes.h")
    ));
}

#[test]
fn header_edits_are_picked_up_on_the_next_lookup() {
    let dir = project();
    let root = dir.path();
    let engine = engine();
    let open = engine
        .open_session(
            "c".into(),
            Some(root.join("main.c").display().to_string()),
            MAIN_C.into(),
            None,
        )
        .unwrap();
    let at = MAIN_C.find("shape_sides(&s)").unwrap();
    assert!(
        !engine
            .query_completions(query(open.session_id, "shape_", at))
            .hits
            .iter()
            .any(|h| h.name == "shape_count")
    );
    std::thread::sleep(std::time::Duration::from_millis(20));
    fs::write(
        root.join("shapes.h"),
        format!("{SHAPES_H}int shape_count(void);\n"),
    )
    .unwrap();
    let later = std::time::SystemTime::now() + std::time::Duration::from_secs(2);
    fs::File::open(root.join("shapes.h"))
        .unwrap()
        .set_modified(later)
        .unwrap();
    assert!(
        engine
            .query_completions(query(open.session_id, "shape_", at))
            .hits
            .iter()
            .any(|h| h.name == "shape_count")
    );
}

#[test]
fn cached_header_scope_is_reused_until_a_header_changes_or_disappears() {
    let dir = project();
    let root = dir.path();
    let engine = engine();
    let open = engine
        .open_session(
            "c".into(),
            Some(root.join("main.c").display().to_string()),
            MAIN_C.into(),
            None,
        )
        .unwrap();
    let id = open.session_id;
    let names = |engine: &ride_engine::Engine| -> Vec<String> {
        ["shape_sides(&s)", "ext_value()"]
            .into_iter()
            .flat_map(|anchor| {
                let at = MAIN_C.find(anchor).unwrap();
                engine
                    .query_completions(query(id, &anchor[..4], at))
                    .hits
                    .into_iter()
                    .map(|h| h.name)
            })
            .collect()
    };
    let first = names(&engine);
    assert!(first.contains(&"shape_sides".to_string()), "{first:?}");
    assert!(first.contains(&"ext_value".to_string()), "{first:?}");
    assert_eq!(names(&engine), first);
    let edit = ride_engine::InputEditFfi {
        start_byte: 0,
        old_end_byte: 0,
        new_end_byte: 0,
        start_row: 0,
        start_column: 0,
        old_end_row: 0,
        old_end_column: 0,
        new_end_row: 0,
        new_end_column: 0,
    };
    engine.apply_edit(id, edit, String::new(), None).unwrap();
    assert_eq!(names(&engine), first);
    fs::remove_file(root.join("include/ext.h")).unwrap();
    let after = names(&engine);
    assert!(after.contains(&"shape_sides".to_string()), "{after:?}");
    assert!(!after.contains(&"ext_value".to_string()), "{after:?}");
}

#[test]
fn a_header_with_cpp_markers_opens_as_cpp() {
    let engine = engine();
    let cpp = engine
        .open_session(
            "h".into(),
            Some("/tmp/sniff.h".into()),
            "#pragma once\nnamespace geo {\nclass Shape {};\n}\n".into(),
            None,
        )
        .unwrap();
    assert_eq!(cpp.lang, Lang::Cpp);
    let c = engine
        .open_session(
            "h".into(),
            Some("/tmp/plain.h".into()),
            "#pragma once\nstruct shape { int sides; };\n".into(),
            None,
        )
        .unwrap();
    assert_eq!(c.lang, Lang::C);
}

#[test]
fn definition_on_an_include_line_opens_the_header() {
    let dir = project();
    let root = dir.path();
    let engine = engine();
    let open = engine
        .open_session(
            "c".into(),
            Some(root.join("main.c").display().to_string()),
            MAIN_C.into(),
            None,
        )
        .unwrap();
    let at = MAIN_C.find("shapes.h").unwrap() + 3;
    let resp = engine.find_definitions(open.session_id, at as u32);
    let symbol = resp.symbol.expect("include symbol");
    assert_eq!(symbol.name, "shapes.h");
    assert_eq!(
        &MAIN_C[symbol.start_byte as usize..symbol.end_byte as usize],
        "shapes.h"
    );
    assert_eq!(resp.hits.len(), 1, "{:?}", resp.hits);
    assert_eq!(resp.hits[0].item_kind, ItemKind::Header);
    assert!(same_file(
        resp.hits[0].source_path.as_deref().unwrap(),
        &root.join("shapes.h")
    ));
    let at = MAIN_C.find("ext.h").unwrap();
    let resp = engine.find_definitions(open.session_id, at as u32);
    assert!(same_file(
        resp.hits[0].source_path.as_deref().unwrap(),
        &root.join("include/ext.h")
    ));
}
