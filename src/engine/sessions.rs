use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{ByteRange, InputEditFfi, SessionOpen, SessionUpdate};
use crate::highlight::BufferSession;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn open_session(
        &self,
        _buffer_id: String,
        path: Option<String>,
        text: String,
        visible: Option<ByteRange>,
    ) -> Result<SessionOpen, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            let lang = crate::highlight::Lang::for_buffer(path.as_deref(), &text);
            let (mut session, update) = BufferSession::open_lang(lang, text, visible)?;
            if let Some(path) = path.as_deref().map(Path::new)
                && lang.clang_name().is_some()
            {
                session.locate(path, crate::check::include_dirs(path));
            }
            self.write(|i| {
                let session_id = i.next_session_id;
                i.next_session_id += 1;
                i.sessions.insert(session_id, session);
                SessionOpen {
                    session_id,
                    lang,
                    update,
                }
            })
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn apply_edit(
        &self,
        session_id: u64,
        edit: InputEditFfi,
        inserted_text: String,
        visible: Option<ByteRange>,
    ) -> Result<SessionUpdate, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            self.write(|i| {
                let session = i
                    .sessions
                    .get_mut(&session_id)
                    .ok_or(EngineError::SessionNotFound { session_id })?;
                session.apply_edit(edit, &inserted_text, visible)
            })?
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn set_visible_range(
        &self,
        session_id: u64,
        visible: ByteRange,
    ) -> Result<SessionUpdate, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            self.write(|i| {
                let session = i
                    .sessions
                    .get_mut(&session_id)
                    .ok_or(EngineError::SessionNotFound { session_id })?;
                session.set_visible(visible)
            })?
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn set_text(
        &self,
        session_id: u64,
        text: String,
        visible: Option<ByteRange>,
    ) -> Result<SessionUpdate, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            self.write(|i| {
                let session = i
                    .sessions
                    .get_mut(&session_id)
                    .ok_or(EngineError::SessionNotFound { session_id })?;
                session.set_text(text, visible)
            })?
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn close_session(&self, session_id: u64) {
        let _ = self.write(|i| {
            i.sessions.remove(&session_id);
            i.latest_query_id.remove(&session_id);
        });
    }
}
