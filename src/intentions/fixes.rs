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
    let primary = &diagnostic.primary;
    if primary.byte_end > primary.byte_start {
        return caret >= primary.byte_start && caret <= primary.byte_end;
    }
    primary.line_start == line
}
