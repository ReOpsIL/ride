use ride_engine::{Diagnostic, DiagnosticFix, DiagnosticLabel, DiagnosticLevel, TextEdit};

pub fn diagnostic(path: &str, start: u32, end: u32, edit: TextEdit) -> Diagnostic {
    Diagnostic {
        level: DiagnosticLevel::Warning,
        message: "unused import".into(),
        code: None,
        primary: DiagnosticLabel {
            path: path.into(),
            byte_start: start,
            byte_end: end,
            line_start: 1,
            line_end: 1,
            column: 1,
            text: None,
            macro_name: None,
        },
        secondary: Vec::new(),
        notes: Vec::new(),
        fixes: vec![DiagnosticFix {
            title: "remove the unused import".into(),
            edits: vec![edit],
        }],
    }
}
