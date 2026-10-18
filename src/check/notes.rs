use std::path::Path;

use crate::ffi::DiagnosticNote;

use super::labels;
use super::message::{self, CompilerMessage};

pub(super) fn notes(
    root: &Path,
    children: &[CompilerMessage],
    primary_path: &str,
) -> Vec<DiagnosticNote> {
    children
        .iter()
        .filter_map(|child| note(root, child, primary_path))
        .collect()
}

fn note(root: &Path, child: &CompilerMessage, primary_path: &str) -> Option<DiagnosticNote> {
    Some(DiagnosticNote {
        level: message::level(&child.level)?,
        message: child.message.clone(),
        labels: labels::labelled(root, &child.spans, primary_path),
    })
}
