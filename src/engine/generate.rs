use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{GenKind, GenOption, TextEdit};
use crate::generate::{self, GenType};
use crate::highlight::{BufferSession, Lang};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn generate_options(&self, session_id: u64, cursor_byte: u32) -> Vec<GenOption> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .map(|s| options_for(s, cursor_byte))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
        .unwrap_or_default()
    }

    pub fn generate_apply(
        &self,
        session_id: u64,
        cursor_byte: u32,
        kind: GenKind,
    ) -> Option<TextEdit> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .and_then(|s| apply_for(s, cursor_byte, kind))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
    }
}

fn resolved(session: &BufferSession, cursor_byte: u32) -> Option<(GenType, u32)> {
    if !matches!(session.lang(), Lang::C | Lang::Cpp) {
        return None;
    }
    let item = generate::enclosing_type(session.outline(), cursor_byte)?.clone();
    let scope = session.scope();
    let ty = GenType::from_scope(&item.name, &scope.types);
    Some((ty, item.end_byte))
}

fn options_for(session: &BufferSession, cursor_byte: u32) -> Vec<GenOption> {
    resolved(session, cursor_byte)
        .map(|(ty, _)| generate::options(&ty))
        .unwrap_or_default()
}

fn apply_for(session: &BufferSession, cursor_byte: u32, kind: GenKind) -> Option<TextEdit> {
    let (ty, end_byte) = resolved(session, cursor_byte)?;
    if ty.fields.is_empty() {
        return None;
    }
    let insert = insert_point(session.replica(), end_byte)?;
    Some(TextEdit {
        start_byte: insert,
        end_byte: insert,
        text: format!("\n{}", generate::apply(&ty, kind)),
        caret_byte: insert,
    })
}

fn insert_point(replica: &str, end_byte: u32) -> Option<u32> {
    let end = (end_byte as usize).min(replica.len());
    replica.as_bytes()[..end]
        .iter()
        .rposition(|&b| b == b'}')
        .map(|p| p as u32)
}
