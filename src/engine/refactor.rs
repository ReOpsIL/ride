use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::ExtractPlan;
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
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .and_then(|s| refactor::extract_variable(s, start_byte, end_byte))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
    }
}
