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
    let at = src.find(after).expect("anchor") + after.len() + prefix.len();
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
    let keywords = names(&engine, id, C_SRC, "return r->", "w");
    assert!(!keywords.iter().any(|(n, _)| n == "while"), "{keywords:?}");
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

const C_CHAINS: &str = "typedef struct point { int x; int y; } point_t;\nstruct rect { point_t origin; int width; };\nstruct rect *find_rect(void);\nstruct rect make_rect(void);\nint main(void) {\n    struct rect box;\n    struct rect *rp = &box;\n    struct rect list[4];\n    box.origin.x = 1;\n    rp->origin.y = 2;\n    list[0].origin.x = 3;\n    (*rp).width = 4;\n    find_rect()->width = 5;\n    make_rect().origin.x = 6;\n    return 0;\n}\n";

const CPP_AUTO: &str = "struct Item { int id; int size() const; };\nstruct Bag { Item first; Item *pick(); Item items[3]; static Bag &instance(); };\nBag make_bag();\nint main() {\n    Bag bag;\n    auto copy = bag;\n    auto made = make_bag();\n    auto lit = Item{1};\n    auto casted = (Item)lit;\n    auto picked = bag.pick();\n    auto &inst = Bag::instance();\n    auto sc = static_cast<Item>(lit);\n    bag.items[1].id = 2;\n    bag.pick()->size();\n    copy.first.id = made.first.id + lit.id + casted.id + picked->id + inst.first.id + sc.id;\n    return 0;\n}\n";

fn plain(engine: &ride_engine::Engine, session: u64, src: &str, after: &str) -> Vec<String> {
    names(engine, session, src, after, "")
        .into_iter()
        .map(|(n, _)| n)
        .collect()
}

#[test]
fn c_field_chains_calls_arrays_and_dereferences_resolve_through_the_type_table() {
    let engine = engine();
    let id = engine
        .open_session(
            "c".into(),
            Some("/tmp/chains.c".into()),
            C_CHAINS.into(),
            None,
        )
        .unwrap()
        .session_id;
    let point = vec!["x".to_string(), "y".to_string()];
    let rect = vec!["origin".to_string(), "width".to_string()];
    assert_eq!(plain(&engine, id, C_CHAINS, "box.origin."), point);
    assert_eq!(plain(&engine, id, C_CHAINS, "rp->origin."), point);
    assert_eq!(plain(&engine, id, C_CHAINS, "list[0]."), rect);
    assert_eq!(plain(&engine, id, C_CHAINS, "list[0].origin."), point);
    assert_eq!(plain(&engine, id, C_CHAINS, "(*rp)."), rect);
    assert_eq!(plain(&engine, id, C_CHAINS, "find_rect()->"), rect);
    assert_eq!(plain(&engine, id, C_CHAINS, "make_rect().origin."), point);
}

#[test]
fn cpp_auto_locals_take_the_type_of_their_initializer() {
    let engine = engine();
    let id = engine
        .open_session(
            "cc".into(),
            Some("/tmp/auto.cc".into()),
            CPP_AUTO.into(),
            None,
        )
        .unwrap()
        .session_id;
    let item = vec!["id".to_string(), "size".to_string()];
    let bag: Vec<String> = ["first", "pick", "items", "instance"]
        .iter()
        .map(|s| s.to_string())
        .collect();
    assert_eq!(plain(&engine, id, CPP_AUTO, "    copy."), bag);
    assert_eq!(plain(&engine, id, CPP_AUTO, "= made."), bag);
    assert_eq!(plain(&engine, id, CPP_AUTO, "+ lit."), item);
    assert_eq!(plain(&engine, id, CPP_AUTO, "+ casted."), item);
    assert_eq!(plain(&engine, id, CPP_AUTO, "+ picked->"), item);
    assert_eq!(plain(&engine, id, CPP_AUTO, "+ inst."), bag);
    assert_eq!(plain(&engine, id, CPP_AUTO, "+ sc."), item);
    assert_eq!(plain(&engine, id, CPP_AUTO, "bag.items[1]."), item);
    assert_eq!(plain(&engine, id, CPP_AUTO, "bag.pick()->"), item);
    let kinds = names(&engine, id, CPP_AUTO, "bag.pick()->", "");
    assert!(
        kinds.contains(&("size".to_string(), ItemKind::Method)),
        "{kinds:?}"
    );
}
