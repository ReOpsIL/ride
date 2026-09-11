use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::PathBuf;

use crate::check::{parse_clang, parse_message_line};
use crate::ffi::Diagnostic;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn parse_cargo_line(&self, line: String) -> Vec<Diagnostic> {
        let root = self.build_root();
        catch_unwind(AssertUnwindSafe(|| parse_message_line(&root, &line))).unwrap_or_default()
    }

    pub fn parse_clang_output(&self, text: String) -> Vec<Diagnostic> {
        catch_unwind(AssertUnwindSafe(|| parse_clang(&text))).unwrap_or_default()
    }
}

impl Engine {
    fn build_root(&self) -> PathBuf {
        self.read(|i| i.workspace.as_ref().map(|w| PathBuf::from(&w.root)))
            .ok()
            .flatten()
            .unwrap_or_default()
    }
}
