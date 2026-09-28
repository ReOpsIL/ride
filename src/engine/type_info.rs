use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::QuickDoc;

use super::Engine;
use super::oracle_ask::ask;

#[uniffi::export]
impl Engine {
    pub fn type_info(&self, session_id: u64, cursor_byte: u32) -> Option<QuickDoc> {
        catch_unwind(AssertUnwindSafe(|| build(self, session_id, cursor_byte)))
            .ok()
            .flatten()
    }
}

fn build(engine: &Engine, session_id: u64, cursor_byte: u32) -> Option<QuickDoc> {
    let (ask, title) = engine
        .read(|i| {
            let title = i
                .sessions
                .get(&session_id)?
                .symbol_at(cursor_byte)
                .map(|s| s.name)
                .unwrap_or_default();
            Some((ask(i, session_id)?, title))
        })
        .ok()
        .flatten()?;
    let hover = ask
        .oracle
        .hover(ask.doc, &ask.stale, cursor_byte as usize)?;
    Some(QuickDoc {
        title,
        signature: hover.code,
        html: crate::markdown::render(&hover.markdown),
        origin_path: String::new(),
        origin_line: 0,
        links: Vec::new(),
    })
}
