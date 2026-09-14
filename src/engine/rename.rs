use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{RenameFile, RenamePlan, TextEdit, UsagesResponse};
use crate::highlight::Lang;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn rename_local(
        &self,
        session_id: u64,
        cursor_byte: u32,
        new_name: String,
    ) -> Vec<TextEdit> {
        catch_unwind(AssertUnwindSafe(|| {
            local(self, session_id, cursor_byte, &new_name)
        }))
        .unwrap_or_default()
    }

    pub fn rename_plan(&self, session_id: u64, cursor_byte: u32, new_name: String) -> RenamePlan {
        catch_unwind(AssertUnwindSafe(|| {
            plan(self, session_id, cursor_byte, &new_name)
        }))
        .unwrap_or_else(|_| RenamePlan::empty())
    }
}

fn local(engine: &Engine, session_id: u64, cursor_byte: u32, new_name: &str) -> Vec<TextEdit> {
    let Some(lang) = session_lang(engine, session_id) else {
        return Vec::new();
    };
    if !valid_identifier(lang, new_name) {
        return Vec::new();
    }
    let ranges = engine
        .read(|i| {
            i.sessions
                .get(&session_id)
                .map(|s| s.local_occurrences(cursor_byte))
        })
        .ok()
        .flatten()
        .unwrap_or_default();
    ranges
        .into_iter()
        .map(|r| text_edit(r.start_byte, r.end_byte, new_name))
        .collect()
}

fn plan(engine: &Engine, session_id: u64, cursor_byte: u32, new_name: &str) -> RenamePlan {
    let Some(lang) = session_lang(engine, session_id) else {
        return RenamePlan::empty();
    };
    if !valid_identifier(lang, new_name) {
        return RenamePlan::empty();
    }
    let resp = engine.find_usages(session_id, cursor_byte);
    if resp.name.is_empty() || resp.hits.is_empty() {
        return RenamePlan::empty();
    }
    plan_from_usages(resp, new_name)
}

pub fn plan_from_usages(resp: UsagesResponse, new_name: &str) -> RenamePlan {
    let UsagesResponse { name, hits, .. } = resp;
    let mut files: Vec<RenameFile> = Vec::new();
    let mut skipped: Vec<String> = Vec::new();
    for hit in hits {
        if !hit.in_definition_scope {
            skipped.push(format!("{}:{}", hit.path, hit.line));
            continue;
        }
        let edit = text_edit(hit.byte_start, hit.byte_end, new_name);
        match files.iter_mut().find(|f| f.path == hit.path) {
            Some(file) => file.edits.push(edit),
            None => files.push(RenameFile {
                path: hit.path,
                edits: vec![edit],
            }),
        }
    }
    for file in &mut files {
        file.edits.sort_by_key(|e| e.start_byte);
    }
    files.sort_by(|a, b| a.path.cmp(&b.path));
    RenamePlan {
        name,
        new_name: new_name.to_string(),
        files,
        skipped,
    }
}

fn session_lang(engine: &Engine, session_id: u64) -> Option<Lang> {
    engine
        .read(|i| i.sessions.get(&session_id).map(|s| s.lang()))
        .ok()
        .flatten()
}

fn text_edit(start: u32, end: u32, new_name: &str) -> TextEdit {
    TextEdit {
        start_byte: start,
        end_byte: end,
        text: new_name.to_string(),
        caret_byte: start + new_name.len() as u32,
    }
}

fn valid_identifier(lang: Lang, name: &str) -> bool {
    let mut chars = name.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    if !(first.is_alphabetic() || first == '_') {
        return false;
    }
    if !chars.all(|c| c.is_alphanumeric() || c == '_') {
        return false;
    }
    !lang.keywords().contains(&name)
}
