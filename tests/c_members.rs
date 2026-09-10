use ride_engine::{
    CompletionContext, CompletionQuery, EngineConfig, ItemKind, QueryMode, engine_start,
};

const C_SRC: &str = "typedef struct point { int x; int y; } point_t;\nstruct rect { point_t origin; int width; };\nint area(struct rect *r) { return r->width * 2; }\nint main(void) {\n    point_t p = { 1, 2 };\n    struct rect box;\n    box.origin.x = p.x;\n    return 0;\n}\n";

const CPP_SRC: &str = "struct Base { int id; void tag(); };\nclass Widget : public Base {\npublic:\n    void draw() const;\n    int width;\nprivate:\n    int secret;\n};\nvoid Widget::draw() const { this->width = 1; }\nWidget make();\nint main() { Widget w; w.draw(); make().width; return 0; }\n";

fn engine() -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn query(session_id: u64, prefix: &str, at: usize) -> CompletionQuery {
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

fn names(
    engine: &ride_engine::Engine,
    session: u64,
    src: &str,
    after: &str,
    prefix: &str,
) -> Vec<(String, ItemKind)> {
    let at = src.find(after).expect("anchor") + after.len();
    engine
        .query_completions(query(session, prefix, at))
        .hits
        .into_iter()
        .map(|h| (h.name, h.item_kind))
        .collect()
}

#[test]
fn c_member_access_lists_struct_fields_through_typedef_and_pointer() {
    let engine = engine();
    let open = engine
        .open_session(
            "c".into(),
            Some("/tmp/members.c".into()),
            C_SRC.into(),
            None,
        )
        .unwrap();
    let id = open.session_id;
    let p = names(&engine, id, C_SRC, "= p.", "");
    assert_eq!(
        p,
        vec![
            ("x".to_string(), ItemKind::Field),
            ("y".to_string(), ItemKind::Field)
        ],
        "{p:?}"
    );
    let boxed = names(&engine, id, C_SRC, "    box.", "");
    let boxed: Vec<_> = boxed.into_iter().map(|(n, _)| n).collect();
    assert_eq!(boxed, vec!["origin", "width"], "{boxed:?}");
    let arrow = names(&engine, id, C_SRC, "return r->", "w");
    assert_eq!(
        arrow,
        vec![("width".to_string(), ItemKind::Field)],
        "{arrow:?}"
    );
    let keywords = names(&engine, id, C_SRC, "return r->", "i");
    assert!(keywords.is_empty(), "{keywords:?}");
}

#[test]
fn cpp_member_access_follows_bases_and_this_in_out_of_class_methods() {
    let engine = engine();
    let open = engine
        .open_session(
            "cc".into(),
            Some("/tmp/members.cc".into()),
            CPP_SRC.into(),
            None,
        )
        .unwrap();
    let id = open.session_id;
    let w: Vec<_> = names(&engine, id, CPP_SRC, "w.", "").into_iter().collect();
    let wn: Vec<&str> = w.iter().map(|(n, _)| n.as_str()).collect();
    assert_eq!(wn, vec!["draw", "width", "secret", "id", "tag"], "{w:?}");
    assert!(w.iter().any(|(n, k)| n == "draw" && *k == ItemKind::Method));
    assert!(w.iter().any(|(n, k)| n == "width" && *k == ItemKind::Field));
    let this: Vec<_> = names(&engine, id, CPP_SRC, "this->", "")
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert_eq!(
        this,
        vec!["draw", "width", "secret", "id", "tag"],
        "{this:?}"
    );
    let unresolved: Vec<_> = names(&engine, id, CPP_SRC, "make().", "")
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert!(unresolved.contains(&"width".to_string()), "{unresolved:?}");
    assert!(unresolved.contains(&"draw".to_string()), "{unresolved:?}");
    assert!(!unresolved.contains(&"main".to_string()), "{unresolved:?}");
    let plain: Vec<_> = names(&engine, id, CPP_SRC, "int main() { ", "W")
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert!(plain.contains(&"Widget".to_string()), "{plain:?}");
}
