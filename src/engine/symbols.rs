use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::ffi::{CompletionHit, DefinitionResponse, OutlineItem};
use crate::query::{IndexSrc, exact_search};

use super::reach::Reach;
use super::{Engine, header_hits};

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
    let snap = engine.read(|i| {
        let session = i.sessions.get(&session_id)?;
        let symbol = session.symbol_at(cursor_byte)?;
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
        ))
    });
    let Ok(Some((symbol, mut hits, catalog, reach, index_dir, index, reader))) = snap else {
        return DefinitionResponse::empty();
    };
    if !catalog {
        hits.extend(header_hits::definitions(reach.headers(), &symbol.name));
        reach.remember(engine);
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
    DefinitionResponse {
        symbol: Some(symbol),
        hits,
    }
}

fn outline_hit(item: &OutlineItem) -> CompletionHit {
    CompletionHit::local(
        &item.name,
        item.kind,
        LOCAL_SCORE,
        Some((item.start_byte, item.end_byte)),
    )
}
