use ride_engine::DiagnosticLevel;

use super::support::{assert_head, assert_note, bare, fix, load, one, span};

#[test]
fn e0308_keeps_the_expectation_span() {
    let diag = one("e0308.jsonl");
    assert_head(&diag, DiagnosticLevel::Error, "E0308", "mismatched types");
    assert_eq!(
        diag.primary,
        span(2, 18, 29, 33, "expected `i32`, found `&str`")
    );
    assert_eq!(
        diag.secondary,
        vec![span(2, 12, 23, 26, "expected due to this")]
    );
}

#[test]
fn unreachable_code_keeps_one_secondary() {
    let diag = one("unreachable.jsonl");
    assert_head(
        &diag,
        DiagnosticLevel::Warning,
        "unreachable_code",
        "unreachable statement",
    );
    assert_eq!(diag.primary, span(3, 5, 28, 39, "unreachable statement"));
    assert_eq!(
        diag.secondary,
        vec![span(
            2,
            5,
            16,
            22,
            "any code following this expression is unreachable"
        )]
    );
    assert_eq!(diag.notes.len(), 1);
    assert_note(
        &diag.notes[0],
        DiagnosticLevel::Note,
        "`#[warn(unreachable_code)]` (part of `#[warn(unused)]`) on by default",
        &[],
    );
    assert!(diag.fixes.is_empty());
}

#[test]
fn unused_imports_do_not_repeat_the_other_primary() {
    let diags = load("unused.jsonl");
    assert_eq!(diags.len(), 2);
    assert_eq!(diags[0].message, "unused imports: `a` and `b`");
    assert_eq!(diags[0].primary, bare(5, 9, 54, 55));
    assert_eq!(diags[1].primary, bare(5, 12, 57, 58));
    assert!(diags.iter().all(|diag| diag.secondary.is_empty()));
    let removal = fix("remove the whole `use` item", 46, 61, "");
    assert_eq!(diags[0].fixes, vec![removal.clone()]);
    assert_eq!(diags[1].fixes, vec![removal]);
    assert_unused_notes(&diags);
}

fn assert_unused_notes(diags: &[ride_engine::Diagnostic]) {
    assert_eq!(diags[0].notes.len(), 2);
    assert!(diags[0].notes.iter().all(|note| note.labels.is_empty()));
    assert_eq!(
        diags[0].notes[0].message,
        "`#[warn(unused_imports)]` (part of `#[warn(unused)]`) on by default"
    );
    assert_eq!(diags[0].notes[1].level, DiagnosticLevel::Help);
    assert_eq!(diags[1].notes[1].message, "remove the whole `use` item");
}
