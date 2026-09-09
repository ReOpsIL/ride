use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::check::{format_source, run_check};
use crate::error::EngineError;
use crate::ffi::CheckResult;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn run_check(&self, project_root: String) -> Result<CheckResult, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            run_check(Path::new(&project_root), None)
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn format_rust(
        &self,
        text: String,
        edition: Option<String>,
    ) -> Result<String, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            format_source(&text, edition.as_deref())
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }
}
