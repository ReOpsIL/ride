use ride_engine::{
    BufferSession, ByteRange, CaptureKind, CompletionQuery, EngineConfig, InputEditFfi, QueryMode,
    engine_start,
};

fn insert_at(text: &str, byte: usize, inserted: &str) -> InputEditFfi {
    let (start_row, start_column) = point(text, byte);
    let mut next = String::new();
    next.push_str(&text[..byte]);
    next.push_str(inserted);
    next.push_str(&text[byte..]);
    let new_end = byte + inserted.len();
    let (new_end_row, new_end_column) = point(&next, new_end);
    InputEditFfi {
        start_byte: byte as u32,
        old_end_byte: byte as u32,
        new_end_byte: new_end as u32,
        start_row,
        start_column,
        old_end_row: start_row,
        old_end_column: start_column,
        new_end_row,
        new_end_column,
    }
}

fn point(text: &str, byte: usize) -> (u32, u32) {
    let mut row = 0u32;
    let mut line_start = 0usize;
    for (i, c) in text.char_indices() {
        if i >= byte {
            break;
        }
        if c == '\n' {
            row += 1;
            line_start = i + 1;
        }
    }
    (row, (byte - line_start) as u32)
}

#[test]
fn utf8_edits_keep_replica() {
    let src = "let x = \"é🦀\";\nlet r = r#\"raw\"#;\n";
    let (mut session, open) = BufferSession::open(src.to_string(), None).unwrap();
    assert!(
        open.highlights
            .iter()
            .any(|h| h.capture == CaptureKind::String)
    );
    let e_at = src.find('é').unwrap();
    session
        .apply_edit(insert_at(src, e_at, "A"), "A", None)
        .unwrap();
    assert_eq!(session.replica(), &src.replacen('é', "Aé", 1));
    let crab = session.replica().find('🦀').unwrap();
    let mid = session.replica().to_string();
    session
        .apply_edit(insert_at(&mid, crab, "B"), "B", None)
        .unwrap();
    assert!(session.replica().contains("B🦀"));
    let after = session.replica().find('🦀').unwrap() + '🦀'.len_utf8();
    let mid = session.replica().to_string();
    session
        .apply_edit(insert_at(&mid, after, "C"), "C", None)
        .unwrap();
    assert!(session.replica().contains("B🦀C"));
    let raw = session.replica().find("raw").unwrap();
    let mid = session.replica().to_string();
    session
        .apply_edit(insert_at(&mid, raw, "Z"), "Z", None)
        .unwrap();
    assert!(session.replica().contains("Zraw"));
}

#[test]
fn small_file_edit_not_clipped_to_viewport() {
    let src = "fn hello() { let x = 1; }\n";
    let vis = ByteRange {
        start_byte: 0,
        end_byte: 2,
    };
    let (mut session, _) = BufferSession::open(src.to_string(), Some(vis)).unwrap();
    let at = src.find("x").unwrap();
    assert!(at > 2);
    let upd = session
        .apply_edit(insert_at(src, at, "y"), "y", Some(vis))
        .unwrap();
    assert!(
        upd.changed.iter().any(|r| r.end_byte as usize > 2),
        "small-file changed ranges must not be clipped to the viewport: {:?}",
        upd.changed
    );
}

fn huge_source() -> String {
    let mut text = String::from("fn head() { let s = \"");
    text.push_str(&"a".repeat(4000));
    text.push_str("\"; }\n");
    text.push_str(&" ".repeat(1024 * 1024));
    text.push_str("\nfn tail_item() {}\n");
    text
}

#[test]
fn huge_scroll_returns_uncovered_spans() {
    let text = huge_source();
    let vis = ByteRange {
        start_byte: 0,
        end_byte: 80,
    };
    let (mut session, open) = BufferSession::open(text.clone(), Some(vis)).unwrap();
    assert!(
        open.highlights
            .iter()
            .all(|h| h.start_byte < 80 + 2048 + 16)
    );
    let end = text.len() as u32;
    let tail = ByteRange {
        start_byte: end.saturating_sub(40),
        end_byte: end,
    };
    let upd = session.set_visible(tail).unwrap();
    assert!(
        !upd.changed.is_empty(),
        "scrolling a huge file into uncovered tail must restyle"
    );
    assert!(
        upd.highlights
            .iter()
            .any(|h| h.capture == CaptureKind::Function || h.capture == CaptureKind::Keyword)
    );
}

#[test]
fn huge_edit_punches_covered_then_scroll_restyles() {
    let text = huge_source();
    let vis = ByteRange {
        start_byte: 0,
        end_byte: 80,
    };
    let (mut session, _) = BufferSession::open(text.clone(), Some(vis)).unwrap();
    let at = text.find("aaa").unwrap();
    session
        .apply_edit(insert_at(&text, at, "X"), "X", Some(vis))
        .unwrap();
    let mid = ByteRange {
        start_byte: 2500,
        end_byte: 3200,
    };
    let upd = session.set_visible(mid).unwrap();
    assert!(
        !upd.changed.is_empty(),
        "off-screen half of a changed node must restyle after scroll"
    );
}

#[test]
fn engine_session_round_trip() {
    let engine = engine_start(EngineConfig {
        index_dir: ".".into(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    let open = engine
        .open_session(
            "buf".into(),
            None,
            "fn foo() { let bar = 1; }\n".into(),
            None,
        )
        .unwrap();
    assert!(
        open.update
            .highlights
            .iter()
            .any(|h| h.capture == CaptureKind::Keyword)
    );
    assert!(
        open.update
            .outline
            .as_ref()
            .is_some_and(|o| o.iter().any(|i| i.name == "foo"))
    );
    let resp = engine.query_completions(CompletionQuery {
        query_id: 7,
        session_id: open.session_id,
        prefix: "ba".into(),
        mode: QueryMode::BufferLocal,
        context: ride_engine::CompletionContext::Unknown,
        cursor_byte: 0,
        replace_start_byte: 0,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    });
    assert!(resp.hits.iter().any(|h| h.name == "bar"));
    engine.close_session(open.session_id);
}

#[test]
fn parse_errors_are_full_list() {
    let (session, open) = BufferSession::open("fn (".into(), None).unwrap();
    assert!(!open.errors.is_empty());
    drop(session);
}

#[test]
fn highlights_fn_name_keyword_and_local() {
    let src = "pub fn item_search() { let searcher = 1; }\n";
    let (_, open) = BufferSession::open(src.to_string(), None).unwrap();
    let hit = |name: &str, kind: CaptureKind| {
        open.highlights.iter().any(|h| {
            let t = &src[h.start_byte as usize..h.end_byte as usize];
            t == name && h.capture == kind
        })
    };
    assert!(hit("fn", CaptureKind::Keyword), "fn keyword");
    assert!(hit("item_search", CaptureKind::Function), "fn name");
    assert!(hit("searcher", CaptureKind::Variable), "local");
}
