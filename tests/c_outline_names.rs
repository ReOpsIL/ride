use ride_engine::{BufferSession, Lang};

#[test]
fn c_outline_names_point_at_the_identifier() {
    let src = "static int s;\nunsigned n;\ntypedef int i;\nint t(void) { return 0; }\nstruct box { int w; };\n";
    let (_session, open) = BufferSession::open_lang(Lang::C, src.to_string(), None).unwrap();
    let outline = open.outline.unwrap();
    for name in ["s", "n", "i", "t", "box"] {
        let item = outline.iter().find(|o| o.name == name).expect(name);
        let at = item.name_start_byte as usize;
        assert_eq!(&src[at..at + name.len()], name, "{name} at {at}");
        let before = src[..at].chars().last().unwrap_or(' ');
        assert!(!before.is_alphanumeric(), "{name} starts mid-word at {at}");
    }
}
