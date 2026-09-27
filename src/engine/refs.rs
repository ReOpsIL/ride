use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;
use std::sync::Arc;

use crate::error::EngineError;
use crate::ffi::UsagesResponse;
use crate::refs::{RefIndex, RefKind, RefRecord, extractor_for, ref_index_dir};

use super::Engine;
use super::bound_refs::BoundRefs;
use super::rel_path::relative;
use super::usages;

#[uniffi::export]
impl Engine {
    pub fn find_usages(&self, session_id: u64, cursor_byte: u32) -> UsagesResponse {
        catch_unwind(AssertUnwindSafe(|| {
            usages::usages(self, session_id, cursor_byte, None)
        }))
        .unwrap_or_else(|_| UsagesResponse::empty())
    }

    pub fn callers(&self, session_id: u64, cursor_byte: u32) -> UsagesResponse {
        let kind = Some(RefKind::Call);
        catch_unwind(AssertUnwindSafe(|| {
            usages::usages(self, session_id, cursor_byte, kind)
        }))
        .unwrap_or_else(|_| UsagesResponse::empty())
    }

    pub fn usage_counts(&self, session_id: u64, names: Vec<String>) -> Vec<u32> {
        catch_unwind(AssertUnwindSafe(|| usages::counts(self, session_id, names)))
            .unwrap_or_default()
    }

    pub fn note_saved(&self, session_id: u64) -> Result<(), EngineError> {
        let snap = self.read(|i| {
            let session = i.sessions.get(&session_id)?;
            let path = session.path()?;
            let rel = relative(i.workspace_root().as_deref(), path);
            Some((session.lang(), rel, session.replica().to_string()))
        })?;
        let Some((lang, rel, text)) = snap else {
            return Ok(());
        };
        let records = extractor_for(lang).extract(lang, &text);
        self.refs_update(rel, records)
    }
}

impl Engine {
    pub fn refs_update(&self, path: String, records: Vec<RefRecord>) -> Result<(), EngineError> {
        match self.ensure_refs()? {
            Some(refs) => refs.update_file(&path, &records),
            None => Ok(()),
        }
    }

    pub(super) fn ensure_refs(&self) -> Result<Option<Arc<RefIndex>>, EngineError> {
        self.write(|i| {
            let Some(root) = i.workspace_root() else {
                i.refs = None;
                return Ok(None);
            };
            if let Some(refs) = i.refs.as_ref().and_then(|b| b.for_root(&root)) {
                return Ok(Some(refs));
            }
            let dir = ref_index_dir(
                Path::new(&i.config.index_dir),
                i.config.refs_dir.as_deref(),
                &root,
            );
            let bound = BoundRefs::new(root.clone(), RefIndex::open(&dir)?);
            let refs = bound.for_root(&root);
            i.refs = Some(bound);
            Ok(refs)
        })?
    }
}
