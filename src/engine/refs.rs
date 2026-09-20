use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::{Path, PathBuf};

use crate::error::EngineError;
use crate::ffi::UsagesResponse;
use crate::refs::{DefContext, RefIndex, RefRecord, build_response, extractor_for, ref_index_dir};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn find_usages(&self, session_id: u64, cursor_byte: u32) -> UsagesResponse {
        match catch_unwind(AssertUnwindSafe(|| usages(self, session_id, cursor_byte))) {
            Ok(resp) => resp,
            Err(_) => UsagesResponse::empty(),
        }
    }

    pub fn usage_counts(&self, session_id: u64, names: Vec<String>) -> Vec<u32> {
        catch_unwind(AssertUnwindSafe(|| counts(self, session_id, names))).unwrap_or_default()
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

    fn ensure_refs(&self) -> Result<(), EngineError> {
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

const MAX_COUNT_NAMES: usize = 200;

fn counts(engine: &Engine, session_id: u64, names: Vec<String>) -> Vec<u32> {
    let names: Vec<String> = names.into_iter().take(MAX_COUNT_NAMES).collect();
    let zeros = || vec![0; names.len()];
    let exists = engine
        .read(|i| i.sessions.contains_key(&session_id))
        .unwrap_or(false);
    if !exists {
        return zeros();
    }
    if engine.ensure_refs().is_err() {
        return zeros();
    }
    let Some(refs) = engine.read(|i| i.refs.clone()).ok().flatten() else {
        return zeros();
    };
    names
        .iter()
        .map(|name| refs.count(name).unwrap_or(0))
        .collect()
}

fn usages(engine: &Engine, session_id: u64, cursor_byte: u32) -> UsagesResponse {
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
    let rows = match refs {
        Some(refs) => refs.usages(&name).unwrap_or_default(),
        None => Vec::new(),
    };
    let root = engine
        .read(|i| i.workspace.as_ref().map(|w| PathBuf::from(&w.root)))
        .ok()
        .flatten();
    build_response(name, rows, root.as_deref(), &ctx)
}

fn symbol_name(session: &crate::highlight::BufferSession, byte: u32) -> Option<String> {
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
