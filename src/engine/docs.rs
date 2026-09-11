use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::ffi::{CompletionHit, OutlineItem, QuickDoc};
use crate::highlight::Lang;
use crate::query::exact_search;

use super::Engine;
use super::doc_block::{self, Lifted};
use super::doc_links;
use super::snapshot::Catalog;

#[uniffi::export]
impl Engine {
    pub fn quick_doc(&self, session_id: u64, cursor_byte: u32) -> Option<QuickDoc> {
        catch_unwind(AssertUnwindSafe(|| build(self, session_id, cursor_byte)))
            .ok()
            .flatten()
    }
}

struct Ctx {
    replica: String,
    lang: Lang,
    path: Option<String>,
    outline: Vec<OutlineItem>,
    catalog: Catalog,
}

struct Loaded {
    text: String,
    lang: Lang,
    path: String,
}

fn build(engine: &Engine, session_id: u64, cursor_byte: u32) -> Option<QuickDoc> {
    let hit = engine
        .find_definitions(session_id, cursor_byte)
        .hits
        .into_iter()
        .next()?;
    let ctx = session(engine, session_id)?;
    let loaded = load(&hit, &ctx);
    let lifted = lift_from(&hit, &loaded);
    Some(assemble(&hit, &ctx, &loaded, lifted))
}

fn session(engine: &Engine, session_id: u64) -> Option<Ctx> {
    engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            Some(Ctx {
                replica: session.replica().to_string(),
                lang: session.lang(),
                path: session.path().map(|p| p.display().to_string()),
                outline: session.outline().to_vec(),
                catalog: Catalog {
                    index_dir: i.config.index_dir.clone(),
                    index: i.index.clone(),
                    reader: i.reader.clone(),
                    overlay: i.overlay.clone(),
                },
            })
        })
        .ok()
        .flatten()
}

fn load(hit: &CompletionHit, ctx: &Ctx) -> Loaded {
    if use_buffer(hit, ctx) {
        return Loaded {
            text: ctx.replica.clone(),
            lang: ctx.lang,
            path: ctx.path.clone().unwrap_or_default(),
        };
    }
    let path = hit.source_path.clone().unwrap_or_default();
    let text = std::fs::read_to_string(&path).unwrap_or_default();
    let lang = Lang::for_buffer(Some(&path), &text);
    Loaded { text, lang, path }
}

fn use_buffer(hit: &CompletionHit, ctx: &Ctx) -> bool {
    match (hit.source_path.as_deref(), ctx.path.as_deref()) {
        (None, _) => true,
        (Some(a), Some(b)) => Path::new(a) == Path::new(b),
        (Some(_), None) => false,
    }
}

fn lift_from(hit: &CompletionHit, loaded: &Loaded) -> Option<Lifted> {
    let byte = hit.byte_start? as usize;
    doc_block::lift(loaded.lang, &loaded.text, byte)
}

fn assemble(hit: &CompletionHit, ctx: &Ctx, loaded: &Loaded, lifted: Option<Lifted>) -> QuickDoc {
    let markdown = match &lifted {
        Some(l) if !l.markdown.is_empty() => l.markdown.clone(),
        _ => hit.doc_paragraph.clone(),
    };
    let rewritten = doc_links::rewrite(&markdown, |p| resolve(p, ctx));
    QuickDoc {
        title: hit.name.clone(),
        signature: hit.signature.clone(),
        html: crate::markdown::render(&rewritten.markdown),
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
    exact_search(ctx.catalog.src(), name, qual, 8)
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
