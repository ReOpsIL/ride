use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::{Path, PathBuf};

use crate::error::EngineError;
use crate::ffi::UsagesResponse;
use crate::refs::{
    DefContext, RefIndex, RefKind, RefRecord, build_response, extractor_for, ref_index_dir,
};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn find_usages(&self, session_id: u64, cursor_byte: u32) -> UsagesResponse {
        match catch_unwind(AssertUnwindSafe(|| {
            usages(self, session_id, cursor_byte, None)
        })) {
            Ok(resp) => resp,
            Err(_) => UsagesResponse::empty(),
        }
    }

    pub fn callers(&self, session_id: u64, cursor_byte: u32) -> UsagesResponse {
        let kind = Some(RefKind::Call);
        match catch_unwind(AssertUnwindSafe(|| {
            usages(self, session_id, cursor_byte, kind)
        })) {
            Ok(resp) => resp,
            Err(_) => UsagesResponse::empty(),
        }
    }

    pub fn note_saved(&self, session_id: u64) -> Result<(), EngineError> {
        let snap = self.read(|i| {
            let session = i.sessions.get(&session_id)?;
            let path = session.path()?.to_path_buf();
            Some((session.lang(), path, session.replica().to_string()))
        })?;
        let Some((lang, path, text)) = snap else {
            return Ok(());
        };
        let root = self.read(|i| i.workspace.as_ref().map(|w| PathBuf::from(&w.root)))?;
        let rel = relative(root.as_deref(), &path);
        let records = extractor_for(lang).extract(lang, &text);
        self.refs_update(rel, records)
    }
}

impl Engine {
    pub fn refs_update(&self, path: String, records: Vec<RefRecord>) -> Result<(), EngineError> {
        self.ensure_refs()?;
        let Some(refs) = self.read(|i| i.refs.clone())? else {
            return Ok(());
        };
        refs.update_file(&path, &records)
    }

    pub(super) fn ensure_refs(&self) -> Result<(), EngineError> {
        self.write(|i| {
            let Some(root) = i.workspace.as_ref().map(|w| PathBuf::from(&w.root)) else {
                return Ok(());
            };
            if i.refs.is_some() && i.refs_root.as_deref() == Some(root.as_path()) {
                return Ok(());
            }
            let dir = ref_index_dir(Path::new(&i.config.index_dir), &root);
            let index = RefIndex::open(&dir)?;
            i.refs = Some(std::sync::Arc::new(index));
            i.refs_root = Some(root);
            Ok(())
        })?
    }
}

fn usages(
    engine: &Engine,
    session_id: u64,
    cursor_byte: u32,
    kind: Option<RefKind>,
) -> UsagesResponse {
    let Ok(Some((name, session_path))) = engine.read(|i| {
        let session = i.sessions.get(&session_id)?;
        let name = symbol_name(session, cursor_byte)?;
        Some((name, session.path().map(Path::to_path_buf)))
    }) else {
        return UsagesResponse::empty();
    };
    let def = engine.find_definitions(session_id, cursor_byte);
    let ctx = DefContext {
        has_definition: !def.hits.is_empty(),
        def_paths: def
            .hits
            .iter()
            .filter_map(|h| definition_path(h, session_path.as_deref()))
            .collect(),
    };
    if engine.ensure_refs().is_err() {
        return UsagesResponse::empty();
    }
    let refs = engine.read(|i| i.refs.clone()).ok().flatten();
    let rows = match (refs, kind) {
        (Some(refs), Some(kind)) => refs.usages_of_kind(&name, kind).unwrap_or_default(),
        (Some(refs), None) => refs.usages(&name).unwrap_or_default(),
        (None, _) => Vec::new(),
    };
    let root = engine
        .read(|i| i.workspace.as_ref().map(|w| PathBuf::from(&w.root)))
        .ok()
        .flatten();
    build_response(name, rows, root.as_deref(), &ctx)
}

pub(super) fn symbol_name(session: &crate::highlight::BufferSession, byte: u32) -> Option<String> {
    if let Some(symbol) = session.symbol_at(byte) {
        return Some(symbol.name);
    }
    session
        .outline()
        .iter()
        .find(|o| o.name_start_byte == byte || o.start_byte == byte)
        .map(|o| o.name.clone())
}

fn definition_path(
    hit: &crate::ffi::CompletionHit,
    session_path: Option<&Path>,
) -> Option<PathBuf> {
    if let Some(path) = hit.source_path.as_ref() {
        return Some(PathBuf::from(path));
    }
    session_path.map(Path::to_path_buf)
}

fn relative(root: Option<&Path>, path: &Path) -> String {
    match root {
        Some(root) => path
            .strip_prefix(root)
            .unwrap_or(path)
            .to_string_lossy()
            .replace('\\', "/"),
        None => path.to_string_lossy().into_owned(),
    }
}
