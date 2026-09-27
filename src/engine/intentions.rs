use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{CompletionHit, Diagnostic, Intention};
use crate::highlight::{BufferSession, Lang, TypeTable};
use crate::intentions::{self, Draft};

use super::include_intentions::IncludeJob;
use super::{Engine, Inner};

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
    let Ok(Some(parts)) = engine.read(|inner| {
        let session = inner.sessions.get(&session_id)?;
        Some(parts(inner, session_id, session, caret, diagnostics, &hits))
    }) else {
        return Vec::new();
    };
    intentions::number(parts.ordered(engine, &hits))
}

enum Reference {
    Ready(Vec<Draft>),
    Includes(IncludeJob),
}

struct Parts {
    fixes: Vec<Draft>,
    reference: Reference,
    rest: Vec<Draft>,
}

impl Parts {
    fn ordered(self, engine: &Engine, hits: &[CompletionHit]) -> Vec<Draft> {
        let mut out = self.fixes;
        match self.reference {
            Reference::Ready(drafts) => out.extend(drafts),
            Reference::Includes(job) => out.extend(job.drafts(engine, hits)),
        }
        out.extend(self.rest);
        out
    }
}

fn parts(
    inner: &Inner,
    session_id: u64,
    session: &BufferSession,
    caret: u32,
    diagnostics: &[Diagnostic],
    hits: &[CompletionHit],
) -> Parts {
    let fixes = intentions::fix_drafts(diagnostics, caret, line_of(session.replica(), caret));
    let mut rest = intentions::underscore_drafts(session, caret);
    rest.extend(arm_drafts(session, caret));
    rest.extend(intentions::refactor_drafts(session, caret));
    let reference = match session.lang() {
        Lang::Rust => Reference::Ready(import_drafts(session, caret, hits)),
        Lang::C | Lang::Cpp if !hits.is_empty() => IncludeJob::take(inner, session_id, session)
            .map_or(Reference::Ready(Vec::new()), Reference::Includes),
        _ => Reference::Ready(Vec::new()),
    };
    Parts {
        fixes,
        reference,
        rest,
    }
}

fn import_drafts(session: &BufferSession, caret: u32, hits: &[CompletionHit]) -> Vec<Draft> {
    match session.symbol_at(caret) {
        Some(symbol) => intentions::import_drafts(session, &symbol.name, hits),
        None => Vec::new(),
    }
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
