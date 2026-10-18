use ride_engine::{Diagnostic, DiagnosticLabel, DiagnosticLevel};

pub fn error_on(path: &str) -> Diagnostic {
    Diagnostic {
        level: DiagnosticLevel::Error,
        message: path.into(),
        code: None,
        primary: located(path),
        secondary: Vec::new(),
        notes: Vec::new(),
        fixes: Vec::new(),
    }
}

pub fn ends(diag: &Diagnostic, suffix: &str) -> bool {
    diag.primary.path.ends_with(suffix)
}

pub fn span(diag: &Diagnostic) -> (u32, u32) {
    (diag.primary.byte_start, diag.primary.byte_end)
}

fn located(path: &str) -> DiagnosticLabel {
    DiagnosticLabel {
        path: path.into(),
        byte_start: 0,
        byte_end: 1,
        line_start: 1,
        line_end: 1,
        column: 1,
        text: None,
        macro_name: None,
    }
}
