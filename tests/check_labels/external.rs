use ride_engine::{Diagnostic, DiagnosticLevel};

use super::support::{SUM_OTHERS, assert_head, assert_note, derived, ext, mapped, one, span};

#[test]
fn println_label_maps_to_the_call_site() {
    let diag = one("println.jsonl");
    assert_head(&diag, DiagnosticLevel::Error, "E0308", "mismatched types");
    assert_eq!(diag.primary, mapped("expected `&usize`, found `&&str`"));
    assert_eq!(
        diag.secondary,
        vec![mapped("arguments to this function are incorrect")]
    );
    assert_eq!(diag.notes.len(), 2);
    assert_note(
        &diag.notes[0],
        DiagnosticLevel::Note,
        "expected reference `&usize`\n   found reference `&&str`",
        &[],
    );
    assert_note(
        &diag.notes[1],
        DiagnosticLevel::Note,
        "associated function defined here",
        &[],
    );
}

#[test]
fn std_span_keeps_its_own_path() {
    let diag = one("std.jsonl");
    assert_head(
        &diag,
        DiagnosticLevel::Error,
        "E0277",
        "a value of type `String` cannot be made by summing an iterator over elements of type `&{integer}`",
    );
    assert_eq!(diag.primary, std_primary());
    assert_eq!(
        diag.secondary,
        vec![span(
            2,
            31,
            42,
            45,
            "required by a bound introduced by this call"
        )]
    );
    assert!(diag.fixes.is_empty());
    assert_std_notes(&diag);
}

#[test]
fn derive_label_maps_to_the_attribute_line() {
    let diag = one("derive.jsonl");
    assert_head(
        &diag,
        DiagnosticLevel::Error,
        "E0277",
        "`NoDebug` doesn't implement `Debug`",
    );
    assert_eq!(
        diag.primary,
        derived(
            3,
            10,
            26,
            31,
            "the trait `Debug` is not implemented for `NoDebug`"
        )
    );
    assert!(diag.secondary.is_empty());
}

fn std_primary() -> ride_engine::DiagnosticLabel {
    span(
        2,
        37,
        48,
        54,
        "value of type `String` cannot be made by summing a `std::iter::Iterator<Item=&{integer}>`",
    )
}

fn assert_std_notes(diag: &Diagnostic) {
    assert_eq!(diag.notes.len(), 4);
    assert_note(
        &diag.notes[0],
        DiagnosticLevel::Help,
        "the trait `Sum<&{integer}>` is not implemented for `String`",
        &[],
    );
    assert_note(&diag.notes[1], DiagnosticLevel::Help, SUM_OTHERS, &[]);
    assert_note(
        &diag.notes[2],
        DiagnosticLevel::Note,
        "the method call chain might not have had the expected associated types",
        &[
            span(2, 14, 25, 34, "this expression has type `[{integer}; 3]`"),
            span(2, 24, 35, 41, "`Iterator::Item` is `&{integer}` here"),
        ],
    );
    assert_std_bound(&diag.notes[3]);
}

fn assert_std_bound(note: &ride_engine::DiagnosticNote) {
    assert_note(
        note,
        DiagnosticLevel::Note,
        "required by a bound in `std::iter::Iterator::sum`",
        &[
            ext(
                3594,
                8,
                120339,
                120342,
                "required by a bound in this associated function",
            ),
            ext(
                3597,
                12,
                120399,
                120414,
                "required by this bound in `Iterator::sum`",
            ),
        ],
    );
}
