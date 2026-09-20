use std::path::{Path, PathBuf};

use crate::ffi::CompletionHit;
use crate::highlight::{BufferSession, IncludeRef, c_include_edit};

use super::draft::Draft;

const MAX_HITS: usize = 5;

pub fn rust_drafts(session: &BufferSession, name: &str, hits: &[CompletionHit]) -> Vec<Draft> {
    if hits.iter().any(in_buffer) {
        return Vec::new();
    }
    let mut seen: Vec<String> = Vec::new();
    let mut out = Vec::new();
    for hit in hits.iter().filter(|hit| hit.name == name).take(MAX_HITS) {
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

#[cfg(test)]
mod tests {
    use super::rust_drafts;
    use crate::ffi::{CompletionHit, ItemKind};
    use crate::highlight::{BufferSession, Lang};

    fn hit(name: &str, path: &str) -> CompletionHit {
        CompletionHit {
            path: path.to_string(),
            name: name.to_string(),
            insert_text: name.to_string(),
            item_kind: ItemKind::Const,
            crate_name: "other".to_string(),
            crate_version: String::new(),
            signature: String::new(),
            doc_first_sentence: String::new(),
            doc_paragraph: String::new(),
            detail: String::new(),
            import_path: None,
            deprecated: false,
            snippet: false,
            replace_start_byte: None,
            source_path: Some("/x/lib.rs".to_string()),
            byte_start: None,
            byte_end: None,
            name_byte: None,
            score: 0.0,
        }
    }

    #[test]
    fn imports_only_names_that_match_exactly() {
        let text = "fn main() {\n    let x = unused;\n}\n".to_string();
        let (session, _) = BufferSession::open_lang(Lang::Rust, text, None).unwrap();
        let hits = [
            hit("UNUSED", "other::UNUSED"),
            hit("unused", "other::unused"),
        ];
        let titles: Vec<String> = rust_drafts(&session, "unused", &hits)
            .into_iter()
            .map(|d| d.title)
            .collect();
        assert_eq!(titles, vec!["Import other::unused".to_string()]);
    }
}
