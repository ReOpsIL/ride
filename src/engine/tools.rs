use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::check::{
    Formatter, format_clang, format_document, format_range, format_source, run_check,
    run_clang_check, selection_span,
};
use crate::error::EngineError;
use crate::ffi::CheckResult;
use crate::highlight::Lang;

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

    pub fn tool_status(&self) -> Vec<crate::ffi::ToolInfo> {
        crate::discover::tool_status()
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
        start_byte: Option<u32>,
        end_byte: Option<u32>,
    ) -> Result<String, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            match selection_span(start_byte, end_byte) {
                Some((start, end)) => {
                    format_range(Lang::Rust, &text, None, edition.as_deref(), start, end)
                }
                None => format_source(&text, edition.as_deref()),
            }
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn format_buffer(
        &self,
        path: Option<String>,
        text: String,
        edition: Option<String>,
    ) -> Result<String, EngineError> {
        let lang = Lang::for_buffer(path.as_deref(), &text);
        match catch_unwind(AssertUnwindSafe(|| {
            format_document(lang, &text, path.as_deref(), edition.as_deref())
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn formatter_name(&self, path: Option<String>, text: String) -> String {
        Formatter::for_lang(Lang::for_buffer(path.as_deref(), &text))
            .filter(|f| f.available())
            .map(|f| f.name().to_string())
            .unwrap_or_default()
    }

    pub fn format_c(
        &self,
        text: String,
        assume_filename: Option<String>,
        start_byte: Option<u32>,
        end_byte: Option<u32>,
    ) -> Result<String, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            match selection_span(start_byte, end_byte) {
                Some((start, end)) => {
                    format_range(Lang::C, &text, assume_filename.as_deref(), None, start, end)
                }
                None => format_clang(&text, assume_filename.as_deref()),
            }
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }
}
