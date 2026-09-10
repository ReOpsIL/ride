use ride_engine::{BufferSession, Lang, Position, Site, SiteAt};

fn site(lang: Lang, src: &str) -> SiteAt {
    let at = src.find('|').expect("caret");
    let text = src.replacen('|', "", 1);
    let (session, _) = BufferSession::open_lang(lang, text, None).unwrap();
    session.site_at(at as u32)
}

fn rust(src: &str) -> SiteAt {
    site(Lang::Rust, src)
}

fn segs(v: &[&str]) -> Vec<String> {
    v.iter().map(|s| s.to_string()).collect()
}

#[test]
fn rust_use_paths() {
    assert_eq!(rust("use |").site, Site::UsePath(vec![]));
    let s = rust("use st|");
    assert_eq!(s.site, Site::UsePath(vec![]));
    assert_eq!(s.prefix, "st");
    assert_eq!(s.replace_start, 4);
    assert_eq!(rust("use std::|").site, Site::UsePath(segs(&["std"])));
    assert_eq!(
        rust("use std::{collections::{HashMap}, io::|").site,
        Site::UsePath(segs(&["std", "io"]))
    );
    let s = rust("use std::{collections::Ha|");
    assert_eq!(s.site, Site::UsePath(segs(&["std", "collections"])));
    assert_eq!(s.prefix, "Ha");
    assert_eq!(
        rust("pub use crate::a::|").site,
        Site::UsePath(segs(&["crate", "a"]))
    );
    assert_ne!(
        rust("use std::collections::HashMap as M|").site,
        Site::UsePath(segs(&["std", "collections"]))
    );
    assert_eq!(
        rust("use a::b;\nfn f() { let x = std::coll|").site,
        Site::ScopedPath(segs(&["std"]))
    );
}

#[test]
fn rust_scoped_member_and_positions() {
    let s = rust("fn f() { let m = HashMap::|");
    assert_eq!(s.site, Site::ScopedPath(segs(&["HashMap"])));
    assert_eq!(rust("fn f() { foo.|").site, Site::MemberAccess);
    let s = rust("fn f() { foo.ba|");
    assert_eq!(s.site, Site::MemberAccess);
    assert_eq!(s.prefix, "ba");
    assert_eq!(
        rust("fn f() { 0..|").site,
        Site::Identifier(Position::Unknown)
    );
    assert_eq!(
        rust("fn f() { let x: |").site,
        Site::Identifier(Position::Type)
    );
    assert_eq!(
        rust("fn f() { let x = |").site,
        Site::Identifier(Position::Value)
    );
    assert_eq!(rust("impl |").site, Site::Identifier(Position::Type));
    assert_eq!(
        rust("fn f(x: &mut |").site,
        Site::Identifier(Position::Type)
    );
}

#[test]
fn rust_attributes_struct_literals_and_vetoes() {
    assert_eq!(rust("#[|").site, Site::Attribute { derive: false });
    let s = rust("#[derive(Cl|");
    assert_eq!(s.site, Site::Attribute { derive: true });
    assert_eq!(s.prefix, "Cl");
    assert_eq!(rust("#![|").site, Site::Attribute { derive: false });
    assert_ne!(
        rust("#[derive(Clone)] struct S|").site,
        Site::Attribute { derive: false }
    );
    assert_eq!(
        rust("struct P { x: i32, y: i32 }\nfn f() { let p = P { x: 1, |y: 2 }; }").site,
        Site::StructLiteral("P".into())
    );
    assert_eq!(rust("fn f() {\n    // a comment ab|\n}").site, Site::None);
    assert_eq!(rust("fn f() { let s = \"hel|lo\"; }").site, Site::None);
    assert_eq!(rust("fn f() { let s = 'a|'; }").site, Site::None);
}

#[test]
fn c_includes_directives_members_and_vetoes() {
    assert_eq!(
        site(Lang::C, "#include <|").site,
        Site::Include {
            quoted: false,
            dir: String::new()
        }
    );
    let s = site(Lang::C, "#include \"sys/ty|");
    assert_eq!(
        s.site,
        Site::Include {
            quoted: true,
            dir: "sys/".into()
        }
    );
    assert_eq!(s.prefix, "ty");
    assert_eq!(s.replace_start, 14);
    assert_eq!(site(Lang::C, "#include <stdio.h>|").site, Site::None);
    let s = site(Lang::C, "#inc|");
    assert_eq!(s.site, Site::Directive);
    assert_eq!(s.prefix, "inc");
    assert_eq!(s.replace_start, 1);
    assert_eq!(site(Lang::C, "  # |").site, Site::Directive);
    assert_eq!(
        site(Lang::C, "#define X |").site,
        Site::Identifier(Position::Unknown)
    );
    assert_eq!(
        site(Lang::C, "int f(struct s *p) { p->|").site,
        Site::MemberAccess
    );
    let s = site(Lang::C, "int f(struct s v) { v.x|");
    assert_eq!(s.site, Site::MemberAccess);
    assert_eq!(s.prefix, "x");
    assert_eq!(
        site(Lang::Cpp, "int main() { std::|").site,
        Site::ScopedPath(segs(&["std"]))
    );
    assert_eq!(
        site(Lang::C, "int main() { std::|").site,
        Site::Identifier(Position::Unknown)
    );
    assert_eq!(site(Lang::C, "/* block com|").site, Site::None);
    assert_eq!(
        site(Lang::C, "int main() { puts(\"he|llo\"); }").site,
        Site::None
    );
    assert_eq!(
        site(Lang::C, "int main() { return |").site,
        Site::Identifier(Position::Value)
    );
    assert_eq!(
        site(Lang::C, "struct |").site,
        Site::Identifier(Position::Type)
    );
}

#[test]
fn plain_languages_take_dashes() {
    let s = site(Lang::Toml, "[dev-dep|");
    assert_eq!(s.site, Site::Identifier(Position::Unknown));
    assert_eq!(s.prefix, "dev-dep");
    assert_eq!(s.replace_start, 1);
    assert_eq!(site(Lang::Markdown, "# Head|").site, Site::None);
}

#[test]
fn rust_imports_list_leaf_names_and_aliases() {
    let src = "use std::collections::{HashMap, BTreeMap as Tree};\nuse serde::Serialize;\nuse std::io::*;\nfn main() {}\n";
    let (session, _) = BufferSession::open_lang(Lang::Rust, src.to_string(), None).unwrap();
    assert_eq!(session.imports(), vec!["HashMap", "Serialize", "Tree"]);
}
