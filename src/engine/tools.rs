use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::check::{format_clang, format_source, run_check, run_clang_check};
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

    pub fn run_check_c(&self, path: String) -> Result<CheckResult, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| run_clang_check(Path::new(&path)))) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn has_tool(&self, name: String) -> bool {
        crate::toolchain::tool_path(&name).is_file()
    }

    pub fn render_markdown(&self, text: String) -> String {
        catch_unwind(AssertUnwindSafe(|| crate::markdown::render(&text))).unwrap_or_default()
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

    pub fn format_c(
        &self,
        text: String,
        assume_filename: Option<String>,
    ) -> Result<String, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            format_clang(&text, assume_filename.as_deref())
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }
}
