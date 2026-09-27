use ride_engine::{BufferSession, CaptureKind, InputEditFfi};

fn replace_one(at: u32) -> InputEditFfi {
    InputEditFfi {
        start_byte: at,
        old_end_byte: at + 1,
        new_end_byte: at + 1,
        start_row: 0,
        start_column: at,
        old_end_row: 0,
        old_end_column: at + 1,
        new_end_row: 0,
        new_end_column: at + 1,
    }
}

#[test]
fn same_length_replacement_repaints_the_token() {
    let src = "fn main() { let a = foo; }\n";
    let (mut session, open) = BufferSession::open(src.to_string(), None).unwrap();
    let at = src.find("foo").unwrap() as u32;
    let before = open.highlights.iter().find(|h| h.start_byte == at).unwrap();
    assert_eq!(before.capture, CaptureKind::Variable);
    let update = session.apply_edit(replace_one(at), "F", None).unwrap();
    assert!(
        update
            .changed
            .iter()
            .any(|r| r.start_byte <= at && r.end_byte >= at + 3),
        "{:?}",
        update.changed
    );
    let after = update
        .highlights
        .iter()
        .find(|h| h.start_byte == at)
        .unwrap();
    assert_ne!(after.capture, CaptureKind::Variable);
}

#[test]
fn queries_inside_a_multibyte_character_do_not_panic() {
    let src = "fn main() { let s = f(\"é🦀\", 1); }\n";
    let (session, _) = BufferSession::open(src.to_string(), None).unwrap();
    let e = src.find('é').unwrap() as u32 + 1;
    let crab = src.find('🦀').unwrap() as u32 + 2;
    for at in [e, crab] {
        let _ = session.site_at(at);
        let _ = session.context_at(at);
        let _ = session.call_site(at);
        let _ = session.bracket_pair(at);
    }
}

#[test]
fn newline_between_items_repaints_only_what_changed() {
    let src = "fn a() {}\n\nfn b() {}\n\nfn c() {}\n";
    let (mut session, _) = BufferSession::open(src.to_string(), None).unwrap();
    let at = src.find("\n\nfn b").unwrap() as u32 + 1;
    let edit = InputEditFfi {
        start_byte: at,
        old_end_byte: at,
        new_end_byte: at + 1,
        start_row: 1,
        start_column: 0,
        old_end_row: 1,
        old_end_column: 0,
        new_end_row: 2,
        new_end_column: 0,
    };
    let update = session.apply_edit(edit, "\n", None).unwrap();
    let painted: u32 = update
        .changed
        .iter()
        .map(|r| r.end_byte - r.start_byte)
        .sum();
    assert!(painted < 12, "{:?}", update.changed);
}
