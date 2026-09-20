use std::path::Path;

use crate::abspath::absolute_string;
use crate::ffi::{DiagnosticFix, TextEdit};

use super::message::{CompilerMessage, Span};

const APPLICABLE: &[&str] = &["MachineApplicable", "MaybeIncorrect"];

pub fn fixes(root: &Path, children: &[CompilerMessage], file: &str) -> Vec<DiagnosticFix> {
    children
        .iter()
        .filter_map(|child| fix(root, child, file))
        .collect()
}

fn fix(root: &Path, child: &CompilerMessage, file: &str) -> Option<DiagnosticFix> {
    let spans: Vec<&Span> = child.spans.iter().filter(|s| applicable(s)).collect();
    if spans.is_empty()
        || spans
            .iter()
            .any(|s| absolute_string(root, &s.file_name) != file)
    {
        return None;
    }
    let caret = spans.last().map(|s| s.byte_end.max(s.byte_start))?;
    Some(DiagnosticFix {
        title: child.message.clone(),
        edits: spans.iter().map(|s| edit(s, caret)).collect(),
    })
}

fn applicable(span: &Span) -> bool {
    span.suggested_replacement.is_some()
        && span
            .suggestion_applicability
            .as_deref()
            .is_some_and(|a| APPLICABLE.contains(&a))
}

fn edit(span: &Span, caret: u32) -> TextEdit {
    TextEdit {
        start_byte: span.byte_start,
        end_byte: span.byte_end.max(span.byte_start),
        text: span.suggested_replacement.clone().unwrap_or_default(),
        caret_byte: caret,
    }
}
