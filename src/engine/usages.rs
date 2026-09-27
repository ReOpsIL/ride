use std::path::{Path, PathBuf};

use crate::ffi::{CompletionHit, UsagesResponse};
use crate::highlight::BufferSession;
use crate::refs::{DefContext, RefKind, build_response};

use super::live_refs::LiveFile;
use super::{Engine, Inner};

const MAX_COUNT_NAMES: usize = 200;

struct Target {
    name: String,
    session_path: Option<PathBuf>,
    root: Option<PathBuf>,
    live: Option<LiveFile>,
}

pub fn counts(engine: &Engine, session_id: u64, names: Vec<String>) -> Vec<u32> {
    let names: Vec<String> = names.into_iter().take(MAX_COUNT_NAMES).collect();
    let exists = engine
        .read(|i| i.sessions.contains_key(&session_id))
        .unwrap_or(false);
    let refs = exists
        .then(|| engine.ensure_refs().ok().flatten())
        .flatten();
    let Some(refs) = refs else {
        return vec![0; names.len()];
    };
    names
        .iter()
        .map(|name| refs.count(name).unwrap_or(0))
        .collect()
}

pub fn usages(
    engine: &Engine,
    session_id: u64,
    cursor_byte: u32,
    kind: Option<RefKind>,
) -> UsagesResponse {
    let Ok(Some(target)) = engine.read(|i| target(i, session_id, cursor_byte)) else {
        return UsagesResponse::empty();
    };
    let def = engine.find_definitions(session_id, cursor_byte);
    let ctx = DefContext {
        has_definition: !def.hits.is_empty(),
        def_paths: def
            .hits
            .iter()
            .filter_map(|h| definition_path(h, target.session_path.as_deref()))
            .collect(),
    };
    let Ok(refs) = engine.ensure_refs() else {
        return UsagesResponse::empty();
    };
    let Some(refs) = refs else {
        return build_response(target.name, Vec::new(), target.root.as_deref(), &ctx);
    };
    let mut rows = match kind {
        Some(kind) => refs.usages_of_kind(&target.name, kind).unwrap_or_default(),
        None => refs.usages(&target.name).unwrap_or_default(),
    };
    let Some(live) = target.live else {
        return build_response(target.name, rows, target.root.as_deref(), &ctx);
    };
    rows.retain(|row| row.path != live.rel);
    let resp = build_response(target.name, rows, target.root.as_deref(), &ctx);
    live.merge(resp, kind, &ctx)
}

fn target(inner: &Inner, session_id: u64, cursor_byte: u32) -> Option<Target> {
    let session = inner.sessions.get(&session_id)?;
    let name = symbol_name(session, cursor_byte)?;
    let root = inner.workspace_root();
    let live = LiveFile::snapshot(session, root.as_deref());
    Some(Target {
        name,
        session_path: session.path().map(Path::to_path_buf),
        root,
        live,
    })
}

pub(super) fn symbol_name(session: &BufferSession, byte: u32) -> Option<String> {
    if let Some(symbol) = session.symbol_at(byte) {
        return Some(symbol.name);
    }
    session
        .outline()
        .iter()
        .find(|o| o.name_start_byte == byte || o.start_byte == byte)
        .map(|o| o.name.clone())
}

fn definition_path(hit: &CompletionHit, session_path: Option<&Path>) -> Option<PathBuf> {
    if let Some(path) = hit.source_path.as_ref() {
        return Some(PathBuf::from(path));
    }
    session_path.map(Path::to_path_buf)
}
