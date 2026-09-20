use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::{Path, PathBuf};

use crate::ffi::{OutlineItem, RenameFile, RenamePlan, TextEdit, UsageHit};
use crate::highlight::Lang;

use super::Engine;
use super::delete_span::deletion_range;

#[uniffi::export]
impl Engine {
    pub fn safe_delete_plan(&self, session_id: u64, cursor_byte: u32) -> RenamePlan {
        catch_unwind(AssertUnwindSafe(|| plan(self, session_id, cursor_byte)))
            .unwrap_or_else(|_| RenamePlan::empty())
    }
}

struct Snap {
    lang: Lang,
    text: String,
    outline: Vec<OutlineItem>,
    path: String,
}

fn plan(engine: &Engine, session_id: u64, cursor_byte: u32) -> RenamePlan {
    let Some(snap) = snap(engine, session_id) else {
        return RenamePlan::empty();
    };
    let Some(item) = named_item(&snap.outline, cursor_byte).cloned() else {
        return RenamePlan::empty();
    };
    let (start, end) = deletion_range(snap.lang, &snap.text, item.start_byte, item.end_byte);
    let usages = engine.find_usages(session_id, cursor_byte);
    let review = review_files(&usages.hits, &snap.path, &item);
    RenamePlan {
        name: item.name,
        new_name: String::new(),
        files: vec![RenameFile {
            path: snap.path,
            edits: vec![deletion_edit(start, end)],
        }],
        review,
    }
}

fn snap(engine: &Engine, session_id: u64) -> Option<Snap> {
    engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            let abs = session.path()?;
            let root = i.workspace.as_ref().map(|w| PathBuf::from(&w.root));
            Some(Snap {
                lang: session.lang(),
                text: session.replica().to_string(),
                outline: session.outline().to_vec(),
                path: relative(root.as_deref(), abs),
            })
        })
        .ok()
        .flatten()
}

fn named_item(outline: &[OutlineItem], byte: u32) -> Option<&OutlineItem> {
    outline
        .iter()
        .filter(|item| covers_name(item, byte))
        .min_by_key(|item| item.end_byte.saturating_sub(item.start_byte))
}

fn covers_name(item: &OutlineItem, byte: u32) -> bool {
    let start = item.name_start_byte;
    let end = start.saturating_add(item.name.len() as u32);
    if start >= end {
        return false;
    }
    (start..end).contains(&byte) || (byte > 0 && (start..end).contains(&(byte - 1)))
}

fn review_files(hits: &[UsageHit], rel: &str, item: &OutlineItem) -> Vec<RenameFile> {
    let mut files: Vec<RenameFile> = Vec::new();
    for hit in hits {
        if inside_item(hit, rel, item) {
            continue;
        }
        let edit = deletion_edit(hit.byte_start, hit.byte_end);
        match files.iter_mut().find(|file| file.path == hit.path) {
            Some(file) => file.edits.push(edit),
            None => files.push(RenameFile {
                path: hit.path.clone(),
                edits: vec![edit],
            }),
        }
    }
    for file in &mut files {
        file.edits.sort_by_key(|e| e.start_byte);
    }
    files.sort_by(|a, b| a.path.cmp(&b.path));
    files
}

fn inside_item(hit: &UsageHit, rel: &str, item: &OutlineItem) -> bool {
    hit.path == rel && hit.byte_start >= item.start_byte && hit.byte_end <= item.end_byte
}

fn deletion_edit(start: u32, end: u32) -> TextEdit {
    TextEdit {
        start_byte: start,
        end_byte: end,
        text: String::new(),
        caret_byte: start,
    }
}

fn relative(root: Option<&Path>, path: &Path) -> String {
    match root {
        Some(root) => path
            .strip_prefix(root)
            .unwrap_or(path)
            .to_string_lossy()
            .replace('\\', "/"),
        None => path.to_string_lossy().into_owned(),
    }
}
