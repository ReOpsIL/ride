use std::path::Path;

use ride_engine::{
    Diagnostic, DiagnosticFix, DiagnosticLabel, DiagnosticLevel, DiagnosticNote, TextEdit,
    parse_lines,
};

pub const SUM_OTHERS: &str = "the following other types implement trait `Sum<A>`:\n  `Duration` implements `Sum<&'a Duration>`\n  `Duration` implements `Sum`\n  `Option<T>` implements `Sum<Option<U>>`\n  `Result<T, E>` implements `Sum<Result<U, E>>`\n  `Saturating<u128>` implements `Sum<&'a Saturating<u128>>`\n  `Saturating<u128>` implements `Sum`\n  `Saturating<u16>` implements `Sum<&'a Saturating<u16>>`\n  `Saturating<u16>` implements `Sum`\nand 88 others";

pub fn load(name: &str) -> Vec<Diagnostic> {
    let text = std::fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/data/check_labels")
            .join(name),
    )
    .unwrap();
    parse_lines(Path::new("/ws"), &text)
}

pub fn one(name: &str) -> Diagnostic {
    let mut diags = load(name);
    assert_eq!(diags.len(), 1, "{name} {:?}", diags);
    diags.pop().unwrap()
}

pub fn span(line: u32, column: u32, start: u32, end: u32, text: &str) -> DiagnosticLabel {
    label(
        "/ws/src/main.rs",
        line,
        column,
        start,
        end,
        Some(text),
        None,
    )
}

pub fn bare(line: u32, column: u32, start: u32, end: u32) -> DiagnosticLabel {
    label("/ws/src/main.rs", line, column, start, end, None, None)
}

pub fn mapped(text: &str) -> DiagnosticLabel {
    label(
        "/ws/src/main.rs",
        1,
        12,
        11,
        33,
        Some(text),
        Some("println!"),
    )
}

pub fn derived(line: u32, column: u32, start: u32, end: u32, text: &str) -> DiagnosticLabel {
    label(
        "/ws/src/main.rs",
        line,
        column,
        start,
        end,
        Some(text),
        Some("#[derive(Debug)]"),
    )
}

pub fn ext(line: u32, column: u32, start: u32, end: u32, text: &str) -> DiagnosticLabel {
    label(
        "/library/core/src/iter/traits/iterator.rs",
        line,
        column,
        start,
        end,
        Some(text),
        None,
    )
}

fn label(
    path: &str,
    line: u32,
    column: u32,
    start: u32,
    end: u32,
    text: Option<&str>,
    macro_name: Option<&str>,
) -> DiagnosticLabel {
    DiagnosticLabel {
        path: path.into(),
        byte_start: start,
        byte_end: end,
        line_start: line,
        line_end: line,
        column,
        text: text.map(str::to_string),
        macro_name: macro_name.map(str::to_string),
    }
}

pub fn fix(title: &str, start: u32, end: u32, text: &str) -> DiagnosticFix {
    DiagnosticFix {
        title: title.into(),
        edits: vec![TextEdit {
            start_byte: start,
            end_byte: end,
            text: text.into(),
            caret_byte: end,
        }],
    }
}

pub fn assert_head(diag: &Diagnostic, level: DiagnosticLevel, code: &str, message: &str) {
    assert_eq!(diag.level, level);
    assert_eq!(diag.code.as_deref(), Some(code));
    assert_eq!(diag.message, message);
}

pub fn assert_note(
    note: &DiagnosticNote,
    level: DiagnosticLevel,
    message: &str,
    labels: &[DiagnosticLabel],
) {
    assert_eq!(note.level, level);
    assert_eq!(note.message, message);
    assert_eq!(note.labels, labels);
}
