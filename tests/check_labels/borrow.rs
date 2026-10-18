use ride_engine::{Diagnostic, DiagnosticFix, DiagnosticLabel, DiagnosticLevel};

use super::support::{assert_head, assert_note, fix, one, span};

#[test]
fn e0382_keeps_labels_note_and_clone_fix() {
    let diag = one("e0382.jsonl");
    assert_head(
        &diag,
        DiagnosticLevel::Error,
        "E0382",
        "borrow of moved value: `rows`",
    );
    assert_eq!(
        diag.primary,
        span(7, 34, 203, 207, "value borrowed here after move")
    );
    assert_eq!(diag.secondary, e0382_secondary());
    assert_e0382_notes(&diag);
    assert_eq!(diag.fixes, vec![e0382_fix()]);
}

fn e0382_secondary() -> Vec<DiagnosticLabel> {
    vec![
        span(
            5,
            9,
            93,
            97,
            "move occurs because `rows` has type `Vec<&str>`, which does not implement the `Copy` trait",
        ),
        span(6, 29, 163, 167, "value moved here"),
    ]
}

fn assert_e0382_notes(diag: &Diagnostic) {
    assert_eq!(diag.notes.len(), 2);
    assert_note(
        &diag.notes[0],
        DiagnosticLevel::Note,
        "consider changing this parameter type in function `sum_by_key` to borrow instead if owning the value isn't necessary",
        &[
            span(10, 4, 236, 246, "in this function"),
            span(
                10,
                21,
                253,
                262,
                "this parameter takes ownership of the value",
            ),
        ],
    );
    assert_note(
        &diag.notes[1],
        DiagnosticLevel::Help,
        "consider cloning the value if the performance cost is acceptable",
        &[],
    );
}

fn e0382_fix() -> DiagnosticFix {
    fix(
        "consider cloning the value if the performance cost is acceptable",
        167,
        167,
        ".clone()",
    )
}

#[test]
fn e0597_orders_four_labels() {
    let diag = one("e0597.jsonl");
    assert_head(
        &diag,
        DiagnosticLevel::Error,
        "E0597",
        "`s` does not live long enough",
    );
    assert_eq!(
        diag.primary,
        span(5, 13, 90, 92, "borrowed value does not live long enough")
    );
    assert_eq!(
        diag.secondary,
        vec![
            span(4, 13, 54, 55, "binding `s` declared here"),
            span(6, 5, 98, 99, "`s` dropped here while still borrowed"),
            span(7, 5, 104, 105, "borrow later used here"),
        ]
    );
    assert!(diag.notes.is_empty());
    assert!(diag.fixes.is_empty());
}

#[test]
fn e0502_orders_three_labels() {
    let diag = one("e0502.jsonl");
    assert_head(
        &diag,
        DiagnosticLevel::Error,
        "E0502",
        "cannot borrow `v` as mutable because it is also borrowed as immutable",
    );
    assert_eq!(
        diag.primary,
        span(4, 5, 57, 66, "mutable borrow occurs here")
    );
    assert_eq!(
        diag.secondary,
        vec![
            span(3, 13, 49, 51, "immutable borrow occurs here"),
            span(5, 20, 87, 88, "immutable borrow later used here"),
        ]
    );
}
