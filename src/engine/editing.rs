use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{BracketPair, ByteRange, FoldRange};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn enclosing_ranges(
        &self,
        session_id: u64,
        start_byte: u32,
        end_byte: u32,
    ) -> Vec<ByteRange> {
        let range = ByteRange {
            start_byte,
            end_byte,
        };
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .map(|s| s.enclosing_ranges(range))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
        .unwrap_or_default()
    }

    pub fn fold_ranges(&self, session_id: u64) -> Vec<FoldRange> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| i.sessions.get(&session_id).map(|s| s.fold_ranges()))
                .ok()
                .flatten()
        }))
        .ok()
        .flatten()
        .unwrap_or_default()
    }

    pub fn bracket_pair(&self, session_id: u64, byte: u32) -> Option<BracketPair> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .and_then(|s| s.bracket_pair(byte))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
    }

    pub fn statement_range(&self, session_id: u64, byte: u32) -> Option<ByteRange> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .and_then(|s| s.statement_range(byte))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
    }

    pub fn sibling_statement_range(
        &self,
        session_id: u64,
        byte: u32,
        up: bool,
    ) -> Option<ByteRange> {
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .and_then(|s| s.sibling_statement(byte, up))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
    }
}
