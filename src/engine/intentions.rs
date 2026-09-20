use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::PathBuf;

use crate::ffi::{CompletionHit, Diagnostic, Intention};
use crate::highlight::{BufferSession, Lang, TypeTable};
use crate::intentions::{self, Draft};

use super::reach::Reach;
use super::{Engine, Inner};

const MAX_HITS: usize = 5;

#[uniffi::export]
impl Engine {
    pub fn intentions(
        &self,
        session_id: u64,
        cursor_byte: u32,
        diagnostics: Vec<Diagnostic>,
    ) -> Vec<Intention> {
        catch_unwind(AssertUnwindSafe(|| {
            collect(self, session_id, cursor_byte, &diagnostics)
        }))
        .unwrap_or_default()
    }
}

fn collect(
    engine: &Engine,
    session_id: u64,
    caret: u32,
    diagnostics: &[Diagnostic],
) -> Vec<Intention> {
    let hits = engine.find_definitions(session_id, caret).hits;
    let drafts = engine
        .read(|inner| match inner.sessions.get(&session_id) {
            Some(session) => sources(inner, session_id, session, caret, diagnostics, &hits),
            None => Vec::new(),
        })
        .unwrap_or_default();
    intentions::number(drafts)
}

fn sources(
    inner: &Inner,
    session_id: u64,
    session: &BufferSession,
    caret: u32,
    diagnostics: &[Diagnostic],
    hits: &[CompletionHit],
) -> Vec<Draft> {
    let mut out = intentions::fix_drafts(diagnostics, caret, line_of(session.replica(), caret));
    out.extend(reference_drafts(inner, session_id, session, hits));
    out.extend(intentions::underscore_drafts(session, caret));
    out.extend(arm_drafts(session, caret));
    out.extend(intentions::refactor_drafts(session, caret));
    out
}

fn reference_drafts(
    inner: &Inner,
    session_id: u64,
    session: &BufferSession,
    hits: &[CompletionHit],
) -> Vec<Draft> {
    match session.lang() {
        Lang::Rust => intentions::import_drafts(session, hits),
        Lang::C | Lang::Cpp => include_drafts(inner, session_id, session, hits),
        _ => Vec::new(),
    }
}

fn include_drafts(
    inner: &Inner,
    session_id: u64,
    session: &BufferSession,
    hits: &[CompletionHit],
) -> Vec<Draft> {
    let Some(clang) = session.lang().clang_name() else {
        return Vec::new();
    };
    let scope = session.scope();
    let system = inner.system_includes.dirs(clang, &[]);
    let reach = Reach::take(inner, session_id, session);
    let headers = reach.headers();
    let mut seen: Vec<PathBuf> = Vec::new();
    let mut out = Vec::new();
    for hit in hits.iter().take(MAX_HITS) {
        let Some(path) = hit.source_path.as_ref().map(PathBuf::from) else {
            continue;
        };
        if seen.contains(&path) {
            continue;
        }
        seen.push(path.clone());
        let Some(header) = headers.iter().find(|h| h.path == path) else {
            continue;
        };
        let dirs = if header.system {
            system.as_slice()
        } else {
            scope.search_dirs.as_slice()
        };
        out.extend(intentions::include_draft(
            session.replica(),
            &path,
            header.system,
            dirs,
            &scope.includes,
        ));
    }
    out
}

fn arm_drafts(session: &BufferSession, caret: u32) -> Vec<Draft> {
    if session.lang() != Lang::Rust {
        return Vec::new();
    }
    let Some(site) = session.match_site(caret) else {
        return Vec::new();
    };
    let scope = session.scope();
    let members = TypeTable::resolve(&[&scope.types], &site.type_name);
    intentions::arm_text(&site, &members, session.replica())
        .map(|edit| Draft::new("Add missing arms", vec![edit]))
        .into_iter()
        .collect()
}

fn line_of(text: &str, byte: u32) -> u32 {
    let at = (byte as usize).min(text.len());
    text.get(..at)
        .map(|head| head.matches('\n').count() as u32 + 1)
        .unwrap_or(1)
}
