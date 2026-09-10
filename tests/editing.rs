use ride_engine::{BufferSession, ByteRange, Lang, engine_start};

fn caret(src: &str) -> (String, ByteRange) {
    let at = src.find('|').expect("caret") as u32;
    let text = src.replacen('|', "", 1);
    (
        text,
        ByteRange {
            start_byte: at,
            end_byte: at,
        },
    )
}

fn selection(src: &str) -> (String, ByteRange) {
    let start = src.find('[').expect("selection start");
    let text = src.replacen('[', "", 1);
    let end = text.rfind(']').expect("selection end");
    (
        text.replacen(']', "", 1),
        ByteRange {
            start_byte: start as u32,
            end_byte: end as u32,
        },
    )
}

fn enclosing(lang: Lang, text: &str, range: ByteRange) -> Vec<String> {
    let (session, _) = BufferSession::open_lang(lang, text.to_string(), None).unwrap();
    let ranges = session.enclosing_ranges(range);
    let mut last: Option<ByteRange> = None;
    for r in &ranges {
        assert!(r.start_byte <= range.start_byte && r.end_byte >= range.end_byte);
        if let Some(l) = last {
            assert!(r.start_byte <= l.start_byte && r.end_byte >= l.end_byte);
            assert_ne!((r.start_byte, r.end_byte), (l.start_byte, l.end_byte));
        }
        last = Some(*r);
    }
    ranges
        .iter()
        .map(|r| text[r.start_byte as usize..r.end_byte as usize].to_string())
        .collect()
}

fn assert_in_order(got: &[String], expected: &[&str]) {
    let mut i = 0;
    for g in got {
        if i < expected.len() && g == expected[i] {
            i += 1;
        }
    }
    assert_eq!(
        i,
        expected.len(),
        "expected {expected:?} in order within {got:?}"
    );
}

fn folds(lang: Lang, text: &str) -> Vec<(String, String)> {
    let (session, _) = BufferSession::open_lang(lang, text.to_string(), None).unwrap();
    let folds = session.fold_ranges();
    let starts: Vec<u32> = folds.iter().map(|f| f.start_byte).collect();
    assert!(starts.windows(2).all(|w| w[0] <= w[1]), "{starts:?}");
    folds
        .iter()
        .map(|f| {
            let hidden = &text[f.start_byte as usize..f.end_byte as usize];
            assert!(hidden.matches('\n').count() >= 2, "{}: {hidden:?}", f.kind);
            (f.kind.clone(), hidden.to_string())
        })
        .collect()
}

fn assert_fold(got: &[(String, String)], kind: &str, hidden: &str) {
    assert!(
        got.iter().any(|(k, h)| k == kind && h == hidden),
        "missing {kind} {hidden:?} in {got:?}"
    );
}

fn bracket(lang: Lang, src: &str) -> Option<(usize, usize)> {
    let (text, at) = caret(src);
    let (session, _) = BufferSession::open_lang(lang, text, None).unwrap();
    session
        .bracket_pair(at.start_byte)
        .map(|p| (p.open_byte as usize, p.close_byte as usize))
}

#[test]
fn rust_enclosing_grows_from_word_through_string_block_and_fn() {
    let (text, at) = caret("fn main() {\n    let s = \"hello wo|rld\";\n    g(s);\n}\n");
    let got = enclosing(Lang::Rust, &text, at);
    assert_in_order(
        &got,
        &[
            "world",
            "hello world",
            "\"hello world\"",
            "let s = \"hello world\";",
            "let s = \"hello world\";\n    g(s);",
            "{\n    let s = \"hello world\";\n    g(s);\n}",
            "fn main() {\n    let s = \"hello world\";\n    g(s);\n}",
            &text,
        ],
    );
    assert_eq!(got[0], "world");
}

#[test]
fn rust_enclosing_from_selection_and_struct_fields() {
    let (text, sel) = selection("struct S {\n    a: u32,\n    [b]: u32,\n}\n");
    let got = enclosing(Lang::Rust, &text, sel);
    assert_in_order(
        &got,
        &[
            "b: u32",
            "a: u32,\n    b: u32,",
            "{\n    a: u32,\n    b: u32,\n}",
            "struct S {\n    a: u32,\n    b: u32,\n}",
        ],
    );
    let (text, at) = caret("fn f() {\n    let c = 'x|';\n}\n");
    let got = enclosing(Lang::Rust, &text, at);
    assert_in_order(&got, &["x", "'x'", "let c = 'x';"]);
    let (text, at) =
        caret("fn f(x: u8) {\n    match x {\n        1 => 2|,\n        _ => 3,\n    }\n}\n");
    let got = enclosing(Lang::Rust, &text, at);
    assert_in_order(&got, &["2", "1 => 2,", "1 => 2,\n        _ => 3,"]);
}

#[test]
fn rust_enclosing_survives_error_nodes() {
    let (text, at) = caret("fn f() {\n    let x = 1;\n}\nfn g|(\n");
    let got = enclosing(Lang::Rust, &text, at);
    assert_eq!(got[0], "g");
    assert_eq!(got.last().unwrap(), &text);
    let (text, at) = caret("fn f() {\n    le|t\n");
    let got = enclosing(Lang::Rust, &text, at);
    assert_eq!(got[0], "let");
    assert_eq!(got.last().unwrap(), &text);
}

#[test]
fn c_enclosing_includes_compound_statement_inside() {
    let (text, at) =
        caret("int f(int a) {\n    if (a) {\n        return a|;\n    }\n    return 0;\n}\n");
    let got = enclosing(Lang::C, &text, at);
    assert_in_order(
        &got,
        &[
            "a",
            "return a;",
            "{\n        return a;\n    }",
            "if (a) {\n        return a;\n    }",
            "if (a) {\n        return a;\n    }\n    return 0;",
            "int f(int a) {\n    if (a) {\n        return a;\n    }\n    return 0;\n}",
        ],
    );
    let (text, at) = caret("const char *s = \"ab|c\";\n");
    let got = enclosing(Lang::C, &text, at);
    assert_in_order(&got, &["abc", "\"abc\"", "const char *s = \"abc\";"]);
}

#[test]
fn other_languages_enclose_by_node() {
    let (text, at) = caret("[package]\nname = \"ri|de\"\nversion = \"1\"\n");
    let got = enclosing(Lang::Toml, &text, at);
    assert_in_order(
        &got,
        &[
            "ride",
            "\"ride\"",
            "name = \"ride\"",
            "[package]\nname = \"ride\"\nversion = \"1\"\n",
        ],
    );
    let (text, at) = caret("all: main.o\n\t$(C|C) -o all main.o\n");
    let got = enclosing(Lang::Make, &text, at);
    assert_in_order(&got, &["CC", "$(CC)", "$(CC) -o all main.o"]);
    let (text, at) = caret("function(f a)\n  set(x| 1)\nendfunction()\n");
    let got = enclosing(Lang::Cmake, &text, at);
    assert_in_order(
        &got,
        &["x", "set(x 1)", "function(f a)\n  set(x 1)\nendfunction()"],
    );
}

#[test]
fn markdown_enclosing_paragraph_item_section_file() {
    let (text, at) =
        caret("# Title\n\nintro\n\n## Sub\n\n- one\n- two wo|rds\n\n## Other\n\ntext\n");
    let got = enclosing(Lang::Markdown, &text, at);
    assert_in_order(
        &got,
        &[
            "words",
            "two words",
            "- two words",
            "## Sub\n\n- one\n- two words",
            "# Title\n\nintro\n\n## Sub\n\n- one\n- two words\n\n## Other\n\ntext",
            &text,
        ],
    );
}

#[test]
fn rust_folds_cover_every_kind() {
    let src = "use a::b;\nuse c;\nuse d;\n\n/// one\n/// two\n/// three\nfn f(x: u8) -> u8 {\n    /* multi\n     * line\n     */\n    if x > 1 {\n        g();\n        h();\n    }\n    match x {\n        1 => 2,\n        _ => 3,\n    }\n}\n\nimpl S {\n    fn g(&self) {\n        a();\n    }\n}\n\ntrait T {\n    fn t(&self);\n    fn u(&self);\n}\n\nmod m {\n    pub fn a() {}\n    pub fn b() {}\n}\n\nstruct S {\n    a: u32,\n    b: u32,\n}\n\nenum E {\n    A,\n    B,\n}\n";
    let got = folds(Lang::Rust, src);
    assert_fold(&got, "use", "\nuse c;\nuse d;\n");
    assert_fold(&got, "comment", "\n/// two\n/// three\n");
    assert_fold(&got, "comment", "\n     * line\n");
    assert_fold(
        &got,
        "fn",
        "\n    /* multi\n     * line\n     */\n    if x > 1 {\n        g();\n        h();\n    }\n    match x {\n        1 => 2,\n        _ => 3,\n    }\n",
    );
    assert_fold(&got, "block", "\n        g();\n        h();\n");
    assert_fold(&got, "match", "\n        1 => 2,\n        _ => 3,\n");
    assert_fold(&got, "impl", "\n    fn g(&self) {\n        a();\n    }\n");
    assert_fold(&got, "fn", "\n        a();\n");
    assert_fold(&got, "trait", "\n    fn t(&self);\n    fn u(&self);\n");
    assert_fold(&got, "mod", "\n    pub fn a() {}\n    pub fn b() {}\n");
    assert_fold(&got, "struct", "\n    a: u32,\n    b: u32,\n");
    assert_fold(&got, "enum", "\n    A,\n    B,\n");
    assert_eq!(got.iter().filter(|(k, _)| k == "block").count(), 1);
}

#[test]
fn rust_folds_ignore_short_and_half_typed_items() {
    let got = folds(
        Lang::Rust,
        "fn a() {}\nfn b() {\n}\nfn c() {\n    x();\n}\nfn d(\n",
    );
    assert_eq!(got.len(), 1);
    assert_fold(&got, "fn", "\n    x();\n");
}

#[test]
fn c_folds_cover_every_kind() {
    let src = "#include <a.h>\n#include <b.h>\n#include \"c.h\"\n\n#ifdef X\nint a;\nint b;\n#else\nint c;\nint d;\n#endif\n\n/* one\n * two\n */\n// l1\n// l2\n// l3\nstruct s {\n    int x;\n    int y;\n};\nenum e {\n    A,\n    B,\n};\nint f(int a) {\n    {\n        int z;\n        int w;\n    }\n    return a;\n}\n";
    let got = folds(Lang::C, src);
    assert_fold(&got, "include", "\n#include <b.h>\n#include \"c.h\"\n");
    assert_fold(&got, "preproc", "\nint a;\nint b;\n");
    assert_fold(&got, "preproc", "\nint c;\nint d;\n");
    assert_fold(&got, "comment", "\n * two\n");
    assert_fold(&got, "comment", "\n// l2\n// l3\n");
    assert_fold(&got, "struct", "\n    int x;\n    int y;\n");
    assert_fold(&got, "enum", "\n    A,\n    B,\n");
    assert_fold(
        &got,
        "fn",
        "\n    {\n        int z;\n        int w;\n    }\n    return a;\n",
    );
    assert_fold(&got, "block", "\n        int z;\n        int w;\n");
    assert_eq!(got.iter().filter(|(k, _)| k == "block").count(), 1);
}

#[test]
fn cpp_folds_class_and_namespace() {
    let src = "namespace n {\nclass C {\npublic:\n    void m() {\n        int x;\n        int y;\n    }\n};\n}\n";
    let got = folds(Lang::Cpp, src);
    assert_fold(
        &got,
        "namespace",
        "\nclass C {\npublic:\n    void m() {\n        int x;\n        int y;\n    }\n};\n",
    );
    assert_fold(
        &got,
        "class",
        "\npublic:\n    void m() {\n        int x;\n        int y;\n    }\n",
    );
    assert_fold(&got, "fn", "\n        int x;\n        int y;\n");
}

#[test]
fn make_folds_define_rule_and_if() {
    let src = "define body\nline one\nline two\nendef\n\nifeq ($(CC),gcc)\nCFLAGS += -O2\nCFLAGS += -g\nelse\nCFLAGS += -O0\nCFLAGS += -g0\nendif\n\nall: main.o\n\t$(CC) -o all main.o\n\techo done\n\nclean:\n\trm -f *.o\n";
    let got = folds(Lang::Make, src);
    assert_fold(&got, "define", "\nline one\nline two\n");
    assert_fold(&got, "if", "\nCFLAGS += -O2\nCFLAGS += -g\n");
    assert_fold(&got, "if", "\nCFLAGS += -O0\nCFLAGS += -g0\n");
    assert_fold(&got, "rule", "\n\t$(CC) -o all main.o\n\techo done\n");
    assert_fold(&got, "rule", "\n\trm -f *.o\n");
}

#[test]
fn toml_folds_tables() {
    let src = "name = \"x\"\n\n[package]\nname = \"a\"\nversion = \"1\"\n\n[[bin]]\nname = \"b\"\npath = \"c\"\n\n[deps]\na = 1\n";
    let got = folds(Lang::Toml, src);
    assert_fold(&got, "table", "\nname = \"a\"\nversion = \"1\"\n");
    assert_fold(&got, "table", "\nname = \"b\"\npath = \"c\"\n");
    assert_fold(&got, "table", "\na = 1\n");
    assert_eq!(got.len(), 3);
}

#[test]
fn cmake_folds_blocks() {
    let src = "function(f a b)\n  set(x 1)\n  set(y 2)\nendfunction()\nmacro(m)\n  set(x 1)\n  set(y 2)\nendmacro()\nif(X)\n  set(a 1)\n  set(b 2)\nelse()\n  set(c 3)\n  set(d 4)\nendif()\nforeach(i 1 2)\n  message(${i})\n  message(x)\nendforeach()\nwhile(Z)\n  set(z 1)\n  set(w 2)\nendwhile()\n";
    let got = folds(Lang::Cmake, src);
    assert_fold(&got, "function", "\n  set(x 1)\n  set(y 2)\n");
    assert_fold(&got, "macro", "\n  set(x 1)\n  set(y 2)\n");
    assert_fold(&got, "if", "\n  set(a 1)\n  set(b 2)\n");
    assert_fold(&got, "if", "\n  set(c 3)\n  set(d 4)\n");
    assert_fold(&got, "foreach", "\n  message(${i})\n  message(x)\n");
    assert_fold(&got, "while", "\n  set(z 1)\n  set(w 2)\n");
}

#[test]
fn markdown_folds_sections_and_fences() {
    let src = "# Title\n\nintro\n\n## Sub\n\n```rust\nfn f() {}\nlet x = 1;\n```\n\n### Deep\n\ntext\n\n## Sub2\n\ntext\n";
    let got = folds(Lang::Markdown, src);
    assert_fold(
        &got,
        "section",
        "\n\nintro\n\n## Sub\n\n```rust\nfn f() {}\nlet x = 1;\n```\n\n### Deep\n\ntext\n\n## Sub2\n\ntext\n",
    );
    assert_fold(
        &got,
        "section",
        "\n\n```rust\nfn f() {}\nlet x = 1;\n```\n\n### Deep\n\ntext\n",
    );
    assert_fold(&got, "section", "\n\ntext\n");
    assert_fold(&got, "fence", "\nfn f() {}\nlet x = 1;\n");
    assert_eq!(got.iter().filter(|(k, _)| k == "section").count(), 4);
}

#[test]
fn brackets_match_with_depth_and_skip_strings_and_comments() {
    let src = "fn f() {\n    g|(a, \")\", h(b), /* ) */ 'c');\n}\n";
    let (text, _) = caret(src);
    let open = text.find("g(").unwrap() + 1;
    let close = text.find("');").unwrap() + 1;
    assert_eq!(bracket(Lang::Rust, src), Some((open, close)));
    let at_close = src.replacen('|', "", 1).replacen("');", "')|;", 1);
    assert_eq!(bracket(Lang::Rust, &at_close), Some((open, close)));
    let inside = "fn f() {\n    let s = \"(|\";\n}\n";
    assert_eq!(bracket(Lang::Rust, inside), None);
    let comment = "fn f() {\n    // (|\n}\n";
    assert_eq!(bracket(Lang::Rust, comment), None);
    let unbalanced = "fn f() {\n    g|(a;\n}\n";
    assert_eq!(bracket(Lang::Rust, unbalanced), None);
    let braces = "fn f() |{\n    let v = [1, (2)];\n}\n";
    let (text, _) = caret(braces);
    assert_eq!(
        bracket(Lang::Rust, braces),
        Some((text.find('{').unwrap(), text.rfind('}').unwrap()))
    );
    assert_eq!(bracket(Lang::Rust, "fn f() {\n    x|\n}\n"), None);
}

#[test]
fn brackets_in_other_languages_and_unterminated_c_string() {
    let c = "int f(void) {\n    char *s = \"unterminated;\n    return |(1);\n}\n";
    let (text, _) = caret(c);
    let open = text.find("(1)").unwrap();
    assert_eq!(bracket(Lang::C, c), Some((open, open + 2)));
    let toml = "a = |[1, \"]\", 2]\n";
    let (text, _) = caret(toml);
    assert_eq!(
        bracket(Lang::Toml, toml),
        Some((text.find('[').unwrap(), text.rfind(']').unwrap()))
    );
    let cmake = "set(x |(\"(\" [[)]]))\n";
    let (text, _) = caret(cmake);
    let open = text.find("(\"").unwrap();
    assert_eq!(bracket(Lang::Cmake, cmake), Some((open, text.len() - 3)));
    let make = "X := $|(shell echo a) # (\n";
    let (text, _) = caret(make);
    assert_eq!(
        bracket(Lang::Make, make),
        Some((text.find('(').unwrap(), text.find(')').unwrap()))
    );
    assert_eq!(bracket(Lang::Markdown, "a |(b)\n"), None);
}

#[test]
fn engine_exports_editor_queries() {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(ride_engine::EngineConfig {
        index_dir: dir.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    });
    let src = "fn main() {\n    let s = (1);\n    g();\n}\n";
    let open = engine
        .open_session("t".into(), Some("main.rs".into()), src.into(), None)
        .unwrap();
    let at = src.find("s = ").unwrap() as u32;
    let ranges = engine.enclosing_ranges(open.session_id, at, at);
    assert_eq!(
        &src[ranges[0].start_byte as usize..ranges[0].end_byte as usize],
        "s"
    );
    assert_eq!(ranges.last().unwrap().end_byte as usize, src.len());
    let folds = engine.fold_ranges(open.session_id);
    assert_eq!(folds.len(), 1);
    assert_eq!(folds[0].kind, "fn");
    let paren = src.find("(1)").unwrap() as u32;
    let pair = engine.bracket_pair(open.session_id, paren).unwrap();
    assert_eq!((pair.open_byte, pair.close_byte), (paren, paren + 2));
    assert!(engine.enclosing_ranges(999, 0, 0).is_empty());
    assert!(engine.fold_ranges(999).is_empty());
    assert!(engine.bracket_pair(999, 0).is_none());
}
