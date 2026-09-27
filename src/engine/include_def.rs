use std::path::Path;

use crate::ffi::{CompletionHit, DefinitionResponse, ItemKind, SymbolAt};
use crate::highlight::include_on_line;

use super::Engine;
use super::reach::Reach;

pub fn definition(
    engine: &Engine,
    session_id: u64,
    cursor_byte: u32,
    score: f32,
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
    let hits = header
        .map(|path| {
            let mut hit =
                CompletionHit::local(&include.name, ItemKind::Header, score, Some((0, 0)));
            hit.source_path = Some(path);
            hit
        })
        .into_iter()
        .collect();
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
