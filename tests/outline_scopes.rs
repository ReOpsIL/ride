use ride_engine::{BufferSession, ItemKind, OutlineItem};

const SRC: &str = "trait Protocol {\n    fn name(&self) -> &str;\n}\n\nstruct Tcp;\n\nimpl Protocol for Tcp {\n    fn name(&self) -> &str {\n        \"tcp\"\n    }\n}\n\nimpl Tcp {\n    fn open() -> Self {\n        Tcp\n    }\n}\n\nmod net {\n    pub struct Udp;\n    impl  Udp\n    {\n        pub fn bind() {}\n    }\n}\n";

fn outline() -> Vec<OutlineItem> {
    let (_, update) = BufferSession::open(SRC.into(), None).unwrap();
    update.outline.unwrap()
}

fn rows(outline: &[OutlineItem]) -> Vec<(&str, Option<&str>)> {
    outline
        .iter()
        .map(|i| (i.name.as_str(), i.scope.as_ref().map(|s| s.label.as_str())))
        .collect()
}

#[test]
fn trait_impl_methods_appear_once() {
    let outline = outline();
    let names = outline
        .iter()
        .filter(|i| i.name == "name" && i.kind == ItemKind::Method)
        .count();
    assert_eq!(names, 2, "{:?}", rows(&outline));
}

#[test]
fn impl_members_carry_their_impl_block() {
    let outline = outline();
    let rows = rows(&outline);
    assert!(
        rows.contains(&("name", Some("impl Protocol for Tcp"))),
        "{rows:?}"
    );
    assert!(rows.contains(&("open", Some("impl Tcp"))), "{rows:?}");
    assert!(rows.contains(&("bind", Some("impl Udp"))), "{rows:?}");
    assert!(rows.contains(&("Tcp", None)), "{rows:?}");
    let trait_name = outline
        .iter()
        .find(|i| i.name == "name" && i.scope.is_none());
    assert!(trait_name.is_some(), "{rows:?}");
}

#[test]
fn scope_spans_the_impl_block() {
    let outline = outline();
    let open = outline.iter().find(|i| i.name == "open").unwrap();
    let scope = open.scope.as_ref().unwrap();
    assert_eq!(
        &SRC[scope.start_byte as usize..scope.start_byte as usize + 8],
        "impl Tcp"
    );
    assert!(SRC[..scope.end_byte as usize].ends_with('}'));
    assert!(scope.start_byte < open.start_byte && open.end_byte <= scope.end_byte);
}
