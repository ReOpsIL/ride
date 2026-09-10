use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{SignatureHelp, TextEdit};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn import_edit(&self, session_id: u64, import_path: String) -> Option<TextEdit> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .and_then(|s| s.import_edit(&import_path))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
    }

    pub fn signature_help(&self, session_id: u64, cursor_byte: u32) -> Option<SignatureHelp> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .and_then(|s| s.signature_help(cursor_byte))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
    }
}
