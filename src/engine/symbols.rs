use std::collections::HashSet;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::ffi::{CompletionHit, DefinitionResponse, OutlineItem, SymbolAt};
use crate::highlight::BufferSession;

use super::catalog::Catalog;
use super::def_rank::RankContext;
use super::reach::Reach;
use super::{Engine, Inner, def_rank, header_hits, include_def, local_defs, variant_hits};

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

struct Lookup {
    symbol: SymbolAt,
    local: Vec<CompletionHit>,
    catalog: Option<Catalog>,
    reach: Reach,
    ctx: RankContext,
}

fn definitions(engine: &Engine, session_id: u64, cursor_byte: u32) -> DefinitionResponse {
    if let Some(resp) = include_def::definition(engine, session_id, cursor_byte, LOCAL_SCORE) {
        return resp;
    }
    match engine.read(|i| lookup(i, session_id, cursor_byte)) {
        Ok(Some(found)) => resolve(engine, found),
        _ => DefinitionResponse::empty(),
    }
}

fn lookup(inner: &Inner, session_id: u64, cursor_byte: u32) -> Option<Lookup> {
    let session = inner.sessions.get(&session_id)?;
    let symbol = session
        .symbol_at(cursor_byte)
        .or_else(|| outline_symbol(session.outline(), cursor_byte))?;
    let reach = Reach::take(inner, session_id, session);
    let local = local_defs::hits(
        session.outline(),
        &reach.scope().types,
        &symbol,
        LOCAL_SCORE,
    );
    Some(Lookup {
        symbol,
        local,
        catalog: session.lang().has_catalog().then(|| Catalog::of(inner)),
        reach,
        ctx: base_context(inner, session),
    })
}

fn resolve(engine: &Engine, found: Lookup) -> DefinitionResponse {
    let Lookup {
        symbol,
        local: mut hits,
        catalog,
        reach,
        mut ctx,
    } = found;
    let headers = if catalog.is_some() {
        &[][..]
    } else {
        reach.headers()
    };
    let tables = header_hits::tables(&reach.scope().types, headers);
    hits.extend(variant_hits::definitions(&tables, &symbol, LOCAL_SCORE));
    match catalog {
        Some(catalog) => hits.extend(catalog.exact(&symbol.name, symbol.qualifier.as_deref(), 20)),
        None => {
            hits.extend(header_hits::definitions(headers, &symbol.name));
            ctx.headers = headers.iter().map(|h| h.path.clone()).collect();
            reach.remember(engine);
        }
    }
    hits.sort_by_key(|h| ctx.tier(h.source_path.as_deref(), &h.crate_name));
    DefinitionResponse {
        symbol: Some(symbol),
        hits,
    }
}

fn base_context(inner: &Inner, session: &BufferSession) -> RankContext {
    let mut crates = def_rank::imported_crates(session.replica());
    if let Some(workspace) = inner.workspace.as_ref() {
        crates.extend(workspace.info.members.iter().cloned());
    }
    RankContext {
        session_path: session.path().map(Path::to_path_buf),
        workspace: inner.workspace.as_ref().map(|w| w.tree.clone()),
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
