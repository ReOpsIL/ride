use std::collections::HashSet;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::{Path, PathBuf};

use crate::ffi::{CompletionHit, DefinitionResponse, ItemKind, OutlineItem, SymbolAt};
use crate::highlight::{BufferSession, include_on_line};
use crate::query::{IndexSrc, exact_search};

use super::def_rank::RankContext;
use super::reach::Reach;
use super::{Engine, Inner, def_rank, header_hits};

const LOCAL_SCORE: f32 = 2000.0;

#[uniffi::export]
impl Engine {
    pub fn find_definitions(&self, session_id: u64, cursor_byte: u32) -> DefinitionResponse {
        match catch_unwind(AssertUnwindSafe(|| {
            definitions(self, session_id, cursor_byte)
        })) {
            Ok(r) => r,
            Err(_) => DefinitionResponse::empty(),
        }
    }
}

fn definitions(engine: &Engine, session_id: u64, cursor_byte: u32) -> DefinitionResponse {
    if let Some(resp) = include_definition(engine, session_id, cursor_byte) {
        return resp;
    }
    let snap = engine.read(|i| {
        let session = i.sessions.get(&session_id)?;
        let symbol = session
            .symbol_at(cursor_byte)
            .or_else(|| outline_symbol(session.outline(), cursor_byte))?;
        let local: Vec<CompletionHit> = session
            .outline()
            .iter()
            .filter(|o| o.name == symbol.name)
            .map(outline_hit)
            .collect();
        Some((
            symbol,
            local,
            session.lang().has_catalog(),
            Reach::take(i, session_id, session),
            i.config.index_dir.clone(),
            i.index.clone(),
            i.reader.clone(),
            base_context(i, session),
        ))
    });
    let Ok(Some((symbol, mut hits, catalog, reach, index_dir, index, reader, mut ctx))) = snap
    else {
        return DefinitionResponse::empty();
    };
    if !catalog {
        hits.extend(header_hits::definitions(reach.headers(), &symbol.name));
        ctx.headers = reach.headers().iter().map(|h| h.path.clone()).collect();
        reach.remember(engine);
        rank(&mut hits, &ctx);
        return DefinitionResponse {
            symbol: Some(symbol),
            hits,
        };
    }
    let src = match (index.as_ref(), reader.as_ref()) {
        (Some(index), Some(reader)) => IndexSrc::Live(index, reader),
        _ => IndexSrc::Dir(Path::new(&index_dir)),
    };
    hits.extend(exact_search(
        src,
        &symbol.name,
        symbol.qualifier.as_deref(),
        20,
    ));
    rank(&mut hits, &ctx);
    DefinitionResponse {
        symbol: Some(symbol),
        hits,
    }
}

pub(crate) fn base_context(inner: &Inner, session: &BufferSession) -> RankContext {
    let mut crates = def_rank::imported_crates(session.replica());
    if let Some(workspace) = inner.workspace.as_ref() {
        crates.extend(workspace.members.iter().cloned());
    }
    RankContext {
        session_path: session.path().map(Path::to_path_buf),
        workspace_root: inner
            .workspace
            .as_ref()
            .map(|w| PathBuf::from(w.root.clone())),
        headers: HashSet::new(),
        crates,
    }
}

pub(crate) fn context(engine: &Engine, session_id: u64) -> RankContext {
    engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            Some(base_context(i, session))
        })
        .ok()
        .flatten()
        .unwrap_or_default()
}

fn rank(hits: &mut [CompletionHit], ctx: &RankContext) {
    hits.sort_by_key(|h| ctx.tier(h.source_path.as_deref(), &h.crate_name));
}

fn include_definition(
    engine: &Engine,
    session_id: u64,
    cursor_byte: u32,
) -> Option<DefinitionResponse> {
    let (include, start, end, reach) = engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            session.lang().clang_name()?;
            let (include, start, end) = include_on_line(session.replica(), cursor_byte as usize)?;
            Some((include, start, end, Reach::take(i, session_id, session)))
        })
        .ok()
        .flatten()?;
    let suffix = Path::new(&include.name);
    let header = reach
        .headers()
        .iter()
        .find(|h| h.path.ends_with(suffix))
        .map(|h| h.path.display().to_string());
    reach.remember(engine);
    let mut hits = Vec::new();
    if let Some(path) = header {
        let mut hit =
            CompletionHit::local(&include.name, ItemKind::Header, LOCAL_SCORE, Some((0, 0)));
        hit.source_path = Some(path);
        hits.push(hit);
    }
    Some(DefinitionResponse {
        symbol: Some(SymbolAt {
            name: include.name,
            start_byte: start as u32,
            end_byte: end as u32,
            qualifier: None,
        }),
        hits,
    })
}

fn outline_hit(item: &OutlineItem) -> CompletionHit {
    CompletionHit::from_outline(item, LOCAL_SCORE, None)
}

fn outline_symbol(outline: &[OutlineItem], byte: u32) -> Option<SymbolAt> {
    let item = outline
        .iter()
        .find(|o| o.name_start_byte == byte || o.start_byte == byte)?;
    let start = item.name_start_byte;
    Some(SymbolAt {
        name: item.name.clone(),
        start_byte: start,
        end_byte: start.saturating_add(item.name.len() as u32),
        qualifier: None,
    })
}
