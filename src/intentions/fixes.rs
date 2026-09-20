use crate::ffi::Diagnostic;

use super::draft::Draft;

pub fn drafts(diagnostics: &[Diagnostic], caret: u32, line: u32) -> Vec<Draft> {
    diagnostics
        .iter()
        .filter(|diagnostic| covers(diagnostic, caret, line))
        .flat_map(|diagnostic| diagnostic.fixes.iter())
        .map(|fix| Draft::new(fix.title.clone(), fix.edits.clone()))
        .collect()
}

fn covers(diagnostic: &Diagnostic, caret: u32, line: u32) -> bool {
    if diagnostic.byte_end > diagnostic.byte_start {
        return caret >= diagnostic.byte_start && caret <= diagnostic.byte_end;
    }
    diagnostic.line == line
}
