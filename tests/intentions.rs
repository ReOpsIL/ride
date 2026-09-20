use std::path::{Path, PathBuf};

use ride_engine::{
    Diagnostic, DiagnosticFix, DiagnosticLevel, Engine, EngineConfig, Intention, TextEdit,
    engine_start, write_index,
};

fn sample(name: &str) -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("samples")
        .join(name)
}

fn fixtures() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn indexed_config(index_dir: &Path) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: Some(fixtures().join("cargo_home").display().to_string()),
        sysroot: Some(fixtures().join("sysroot").display().to_string()),
        offline_metadata: true,
        refs_dir: None,
    }
}

fn engine() -> std::sync::Arc<Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
    })
}

fn open(engine: &Engine, path: &Path, text: &str) -> u64 {
    engine
        .open_session(
            "s".into(),
            Some(path.display().to_string()),
            text.to_string(),
            None,
        )
        .unwrap()
        .session_id
}

fn at(text: &str, needle: &str) -> u32 {
    text.find(needle).expect(needle) as u32
}

fn titles(items: &[Intention]) -> Vec<String> {
    items.iter().map(|i| i.title.clone()).collect()
}

fn applied(text: &str, intention: &Intention) -> String {
    let mut out = text.to_string();
    let mut edits = intention.edits.clone();
    edits.sort_by_key(|e| std::cmp::Reverse(e.start_byte));
    for edit in edits {
        out.replace_range(edit.start_byte as usize..edit.end_byte as usize, &edit.text);
    }
    out
}

fn diagnostic(path: &str, start: u32, end: u32, edit: TextEdit) -> Diagnostic {
    Diagnostic {
        path: path.into(),
        byte_start: start,
        byte_end: end,
        line: 1,
        column: 1,
        level: DiagnosticLevel::Warning,
        message: "unused import".into(),
        code: None,
        fixes: vec![DiagnosticFix {
            title: "remove the unused import".into(),
            edits: vec![edit],
        }],
    }
}

#[test]
fn diagnostic_fix_at_the_caret_comes_first() {
    let engine = engine();
    let path = sample("rust-demo/src/main.rs");
    let text = std::fs::read_to_string(&path).unwrap();
    let id = open(&engine, &path, &text);
    let start = at(&text, "use std::collections::HashMap;");
    let end = start + "use std::collections::HashMap;".len() as u32;
    let fix = TextEdit {
        start_byte: start,
        end_byte: end,
        text: String::new(),
        caret_byte: start,
    };
    let diag = diagnostic(&path.display().to_string(), start, end, fix);
    let found = engine.intentions(id, start + 4, vec![diag]);
    assert_eq!(
        found.first().map(|i| i.title.clone()),
        Some("remove the unused import".into()),
        "{:?}",
        titles(&found)
    );
    assert_eq!(found.first().map(|i| i.id), Some(0));
}

#[test]
fn missing_import_is_offered() {
    let dir = tempfile::tempdir().unwrap();
    let config = indexed_config(dir.path());
    write_index(&fixtures().join("sample_crate"), dir.path(), &config).unwrap();
    let engine = engine_start(config);
    let path = fixtures().join("sample_crate/src/other.rs");
    let text = "fn make() {\n    let f = Foo::new();\n    let _ = f;\n}\n";
    let id = open(&engine, &path, text);
    let found = engine.intentions(id, at(text, "Foo") + 1, Vec::new());
    let wanted = found
        .iter()
        .find(|i| i.title.starts_with("Import ") && i.title.contains("Foo"))
        .unwrap_or_else(|| panic!("{:?}", titles(&found)));
    assert!(
        applied(text, wanted).starts_with("use "),
        "{}",
        applied(text, wanted)
    );
}

#[test]
fn unused_local_is_offered_an_underscore() {
    let engine = engine();
    let path = sample("rust-demo/src/main.rs");
    let text = "fn main() {\n    let unused = 1;\n}\n";
    let id = open(&engine, &path, text);
    let found = engine.intentions(id, at(text, "unused") + 2, Vec::new());
    let wanted = found
        .iter()
        .find(|i| i.title == "Rename to _unused")
        .unwrap_or_else(|| panic!("{:?}", titles(&found)));
    assert!(applied(text, wanted).contains("let _unused = 1;"));
}

#[test]
fn missing_match_arm_is_offered() {
    let engine = engine();
    let path = sample("rust-demo/src/main.rs");
    let text = concat!(
        "enum Dir {\n    North,\n    South(u32),\n}\n\n",
        "fn go(d: Dir) -> u32 {\n",
        "    match d {\n        Dir::North => 1,\n    }\n",
        "}\n"
    );
    let id = open(&engine, &path, text);
    let found = engine.intentions(id, at(text, "Dir::North => 1,"), Vec::new());
    let wanted = found
        .iter()
        .find(|i| i.title == "Add missing arms")
        .unwrap_or_else(|| panic!("{:?}", titles(&found)));
    let out = applied(text, wanted);
    assert!(out.contains("        Dir::South(..) => todo!(),"), "{out}");
    assert!(!out.contains("Dir::North => todo!()"), "{out}");
}

#[test]
fn covered_match_offers_no_arms() {
    let engine = engine();
    let path = sample("rust-demo/src/main.rs");
    let text = concat!(
        "enum Dir {\n    North,\n    South,\n}\n\n",
        "fn go(d: Dir) -> u32 {\n",
        "    match d {\n        Dir::North => 1,\n        Dir::South => 2,\n    }\n",
        "}\n"
    );
    let id = open(&engine, &path, text);
    let found = engine.intentions(id, at(text, "Dir::North => 1,"), Vec::new());
    assert!(!titles(&found).contains(&"Add missing arms".to_string()));
}

#[test]
fn wildcard_match_offers_no_arms() {
    let engine = engine();
    let path = sample("rust-demo/src/main.rs");
    let text = concat!(
        "enum Dir {\n    North,\n    South,\n}\n\n",
        "fn go(d: Dir) -> u32 {\n",
        "    match d {\n        Dir::North => 1,\n        _ => 2,\n    }\n",
        "}\n"
    );
    let id = open(&engine, &path, text);
    let found = engine.intentions(id, at(text, "Dir::North => 1,"), Vec::new());
    assert!(!titles(&found).contains(&"Add missing arms".to_string()));
}

#[test]
fn literal_at_the_caret_offers_introduce_constant() {
    let engine = engine();
    let path = sample("rust-demo/src/main.rs");
    let text = std::fs::read_to_string(&path).unwrap();
    let id = open(&engine, &path, &text);
    let found = engine.intentions(id, at(&text, "\"ride\""), Vec::new());
    let wanted = found
        .iter()
        .find(|i| i.title == "Introduce Constant")
        .unwrap_or_else(|| panic!("{:?}", titles(&found)));
    assert!(applied(&text, wanted).contains("const VALUE: &str = \"ride\";"));
}
