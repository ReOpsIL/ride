use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::ExtractPlan;
use crate::highlight::BufferSession;
use crate::refactor;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn extract_variable(
        &self,
        session_id: u64,
        start_byte: u32,
        end_byte: u32,
    ) -> Option<ExtractPlan> {
        self.plan(session_id, |s| {
            refactor::extract_variable(s, start_byte, end_byte)
        })
    }

    pub fn introduce_constant(
        &self,
        session_id: u64,
        start_byte: u32,
        end_byte: u32,
    ) -> Option<ExtractPlan> {
        self.plan(session_id, |s| {
            refactor::introduce_constant(s, start_byte, end_byte)
        })
    }

    pub fn inline_variable(&self, session_id: u64, cursor_byte: u32) -> Option<ExtractPlan> {
        self.plan(session_id, |s| refactor::inline_variable(s, cursor_byte))
    }
}

impl Engine {
    fn plan(
        &self,
        session_id: u64,
        build: impl Fn(&BufferSession) -> Option<ExtractPlan>,
    ) -> Option<ExtractPlan> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| i.sessions.get(&session_id).and_then(&build))
                .ok()
                .flatten()
        }))
        .ok()
        .flatten()
    }
}
