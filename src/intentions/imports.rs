use std::path::{Path, PathBuf};

use crate::ffi::CompletionHit;
use crate::highlight::{BufferSession, IncludeRef, c_include_edit};

use super::draft::Draft;

const MAX_HITS: usize = 5;

pub fn rust_drafts(session: &BufferSession, hits: &[CompletionHit]) -> Vec<Draft> {
    if hits.iter().any(in_buffer) {
        return Vec::new();
    }
    let mut seen: Vec<String> = Vec::new();
    let mut out = Vec::new();
    for hit in hits.iter().take(MAX_HITS) {
        if !hit.path.contains("::") || seen.contains(&hit.path) {
            continue;
        }
        seen.push(hit.path.clone());
        if let Some(edit) = session.import_edit(&hit.path) {
            out.push(Draft::new(format!("Import {}", hit.path), vec![edit]));
        }
    }
    out
}

pub fn include_draft(
    text: &str,
    header: &Path,
    system: bool,
    dirs: &[PathBuf],
    includes: &[IncludeRef],
) -> Option<Draft> {
    let name = c_include_edit::name(header, dirs)?;
    if includes.iter().any(|include| include.name == name) {
        return None;
    }
    let edit = c_include_edit::edit(text, &name, !system)?;
    Some(Draft::new(format!("Include {name}"), vec![edit]))
}

fn in_buffer(hit: &CompletionHit) -> bool {
    hit.crate_name.is_empty() && hit.source_path.is_none()
}
