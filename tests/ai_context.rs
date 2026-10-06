use std::sync::Arc;

use ride_engine::{AiContext, Engine, EngineConfig, engine_start};

const SRC: &str = "struct Point {\n    x: i32,\n    y: i32,\n}\n\nfn scale(p: &Point, k: i32) -> Point {\n    Point { x: p.x * k, y: p.y * k }\n}\n\nfn main() {\n    let p = Point { x: 1, y: 2 };\n    let q = scale(&p, 3);\n    println!(\"{}\", q.x);\n}\n";

fn fresh() -> (tempfile::TempDir, Arc<Engine>) {
    let dir = tempfile::tempdir().unwrap();
    let engine = engine_start(EngineConfig {
        index_dir: dir.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    });
    (dir, engine)
}

fn context(start: &str, end: &str, budget: u32) -> AiContext {
    let (_dir, engine) = fresh();
    let open = engine
        .open_session(
            "buf".into(),
            Some("/w/src/main.rs".into()),
            SRC.into(),
            None,
        )
        .unwrap();
    let from = SRC.find(start).unwrap() as u32;
    let to = SRC.find(end).unwrap() as u32 + end.len() as u32;
    engine
        .ai_context(open.session_id, from, to, budget)
        .expect("a context for an open session")
}

#[test]
fn selection_brings_its_enclosing_item_and_referenced_definitions() {
    let ctx = context("let q", "3);", 20_000);
    assert_eq!(ctx.language, "rust");
    assert_eq!(ctx.focus.text, "    let q = scale(&p, 3);\n");
    assert_eq!(ctx.focus.line, 12);
    let enclosing = ctx.enclosing.expect("main encloses the selection");
    assert!(
        enclosing.text.starts_with("fn main()"),
        "{}",
        enclosing.text
    );
    let labels: Vec<_> = ctx.related.iter().map(|s| s.label.as_str()).collect();
    assert!(labels.iter().any(|l| l.starts_with("scale")), "{labels:?}");
    let scale = ctx
        .related
        .iter()
        .find(|s| s.label.starts_with("scale"))
        .unwrap();
    assert!(scale.text.starts_with("fn scale"), "{}", scale.text);
    assert_eq!(scale.line, 6);
}

#[test]
fn definitions_already_inside_the_shown_code_are_not_repeated() {
    let ctx = context("struct Point", "\n}\n\nfn main", 20_000);
    assert!(
        ctx.related.iter().all(|s| !s.label.starts_with("scale")),
        "{:?}",
        ctx.related
    );
}

#[test]
fn a_small_budget_clips_and_marks_the_focus() {
    let ctx = context("fn scale", "\n}\n\nfn main", 40);
    assert!(ctx.focus.truncated);
    assert!(ctx.focus.text.len() <= 40);
    assert!(ctx.related.is_empty());
}

#[test]
fn unknown_sessions_have_no_context() {
    let (_dir, engine) = fresh();
    assert!(engine.ai_context(999, 0, 0, 1000).is_none());
}
