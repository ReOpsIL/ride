use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{CompletionHit, DefinitionResponse, OutlineItem, QuickDoc};

use super::Engine;
use super::catalog::Catalog;
use super::doc_block::{self, Lifted};
use super::hit_source::{self, Buffer, Loaded};
use super::{doc_html, doc_links};

#[uniffi::export]
impl Engine {
    pub fn quick_doc(&self, session_id: u64, cursor_byte: u32) -> Option<QuickDoc> {
        catch_unwind(AssertUnwindSafe(|| build(self, session_id, cursor_byte)))
            .ok()
            .flatten()
    }
}

struct Ctx {
    buffer: Buffer,
    outline: Vec<OutlineItem>,
    catalog: Catalog,
}

fn build(engine: &Engine, session_id: u64, cursor_byte: u32) -> Option<QuickDoc> {
    let own = super::symbols::own_definitions(engine, session_id, cursor_byte);
    let ctx = session(engine, session_id)?;
    if let Some(page) = primitive_page(engine, session_id, cursor_byte, &own, &ctx) {
        return Some(page);
    }
    let found = if own.hits.is_empty() {
        super::oracle_defs::definition(engine, session_id, cursor_byte).unwrap_or(own)
    } else {
        own
    };
    let hit = found.hits.into_iter().next()?;
    let disk = hit_source::file_of(&hit, Some(&ctx.buffer));
    let loaded = hit_source::load(disk, Some(&ctx.buffer));
    let lifted = lift_from(&hit, &loaded, disk.is_some());
    Some(assemble(&hit, &ctx, &loaded, lifted))
}

fn primitive_page(
    engine: &Engine,
    session_id: u64,
    cursor_byte: u32,
    found: &DefinitionResponse,
    ctx: &Ctx,
) -> Option<QuickDoc> {
    let name = found.symbol.as_ref()?.name.clone();
    if !names_a_type(engine, session_id, cursor_byte) {
        return None;
    }
    let prim = super::primitive_doc::lift(&name)?;
    let rewritten = doc_links::rewrite(&prim.markdown, |p| resolve(p, ctx));
    Some(QuickDoc {
        title: name.clone(),
        signature: name,
        html: crate::markdown::render(&doc_html::inert(&rewritten.markdown)),
        origin_path: prim.path,
        origin_line: prim.line,
        links: rewritten.links,
    })
}

fn names_a_type(engine: &Engine, session_id: u64, cursor_byte: u32) -> bool {
    engine
        .read(|i| {
            i.sessions
                .get(&session_id)
                .is_some_and(|session| session.names_type(cursor_byte))
        })
        .unwrap_or(false)
}

fn session(engine: &Engine, session_id: u64) -> Option<Ctx> {
    engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            Some(Ctx {
                buffer: Buffer::of(session),
                outline: session.outline().to_vec(),
                catalog: Catalog::of(i),
            })
        })
        .ok()
        .flatten()
}

fn lift_from(hit: &CompletionHit, loaded: &Loaded, disk: bool) -> Option<Lifted> {
    let byte = hit.name_byte.or(hit.byte_start).unwrap_or(0) as usize;
    let read = || doc_block::lift_named(loaded.lang, &loaded.text, byte, &hit.name);
    if disk {
        super::doc_cache::cached(&loaded.path, &hit.name, read)
    } else {
        read()
    }
}

fn assemble(hit: &CompletionHit, ctx: &Ctx, loaded: &Loaded, lifted: Option<Lifted>) -> QuickDoc {
    let markdown = match &lifted {
        Some(l) => l.markdown.clone(),
        None => hit.doc_paragraph.clone(),
    };
    let rewritten = doc_links::rewrite(&markdown, |p| resolve(p, ctx));
    QuickDoc {
        title: hit.name.clone(),
        signature: hit.signature.clone(),
        html: crate::markdown::render(&doc_html::inert(&rewritten.markdown)),
        origin_path: origin(hit, loaded),
        origin_line: origin_line(&lifted, hit, loaded),
        links: rewritten.links,
    }
}

fn origin_line(lifted: &Option<Lifted>, hit: &CompletionHit, loaded: &Loaded) -> u32 {
    if let Some(l) = lifted {
        return doc_block::line_at(&loaded.text, l.start_byte);
    }
    hit.byte_start
        .map(|b| doc_block::line_at(&loaded.text, b as usize))
        .unwrap_or(0)
}

fn origin(hit: &CompletionHit, loaded: &Loaded) -> String {
    if loaded.path.is_empty() {
        hit.source_path.clone().unwrap_or_default()
    } else {
        loaded.path.clone()
    }
}

fn resolve(path: &str, ctx: &Ctx) -> Option<String> {
    let path = path.trim().trim_start_matches("crate::");
    if local(path, &ctx.outline) {
        return Some(path.to_string());
    }
    let (name, qual) = split(path);
    ctx.catalog
        .exact(name, qual, 8)
        .into_iter()
        .next()
        .map(|h| h.path)
}

fn local(path: &str, outline: &[OutlineItem]) -> bool {
    let (name, qual) = split(path);
    let has_name = outline.iter().any(|o| o.name == name);
    match qual {
        None => has_name,
        Some(q) => {
            let owner = q.rsplit("::").next().unwrap_or(q);
            has_name && outline.iter().any(|o| o.name == owner)
        }
    }
}

fn split(path: &str) -> (&str, Option<&str>) {
    match path.rsplit_once("::") {
        Some((q, n)) if !n.is_empty() => (n, Some(q)),
        _ => (path, None),
    }
}
