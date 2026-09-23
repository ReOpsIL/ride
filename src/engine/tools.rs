use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::check::{
    Formatter, check_c_live, format_clang, format_document, format_range, format_source, run_check,
    run_check_c_project, run_clang_check, selection_span, sources_including,
};
use crate::error::EngineError;
use crate::ffi::CheckResult;
use crate::highlight::Lang;

use super::Engine;

#[uniffi::export]
impl Engine {
    #[uniffi::method(default(clippy = false))]
    pub fn run_check(
        &self,
        project_root: String,
        clippy: bool,
    ) -> Result<CheckResult, EngineError> {
        let project = Path::new(&project_root);
        let workspace_root = self.cargo_root(project);
        self.guard(|| run_check(project, &workspace_root, None, clippy))
    }

    pub fn run_check_c(&self, path: String) -> Result<CheckResult, EngineError> {
        self.guard(|| run_clang_check(Path::new(&path)))
    }

    pub fn check_c_live(&self, path: String, text: String) -> Result<CheckResult, EngineError> {
        self.guard(|| check_c_live(Path::new(&path), &text))
    }

    pub fn run_check_c_project(&self, root: String) -> Result<CheckResult, EngineError> {
        self.guard(|| run_check_c_project(Path::new(&root)))
    }

    pub fn sources_including(&self, header: String) -> Vec<String> {
        catch_unwind(AssertUnwindSafe(|| {
            sources_including(Path::new(&header))
                .into_iter()
                .map(|p| p.display().to_string())
                .collect()
        }))
        .unwrap_or_default()
    }

    pub fn tool_status(&self) -> Vec<crate::ffi::ToolInfo> {
        crate::discover::tool_status()
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
        self.guard(|| match selection_span(start_byte, end_byte) {
            Some((start, end)) => {
                format_range(Lang::Rust, &text, None, edition.as_deref(), start, end)
            }
            None => format_source(&text, edition.as_deref()),
        })
    }

    pub fn format_buffer(
        &self,
        path: Option<String>,
        text: String,
        edition: Option<String>,
    ) -> Result<String, EngineError> {
        let lang = Lang::for_buffer(path.as_deref(), &text);
        self.guard(|| format_document(lang, &text, path.as_deref(), edition.as_deref()))
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
        self.guard(|| match selection_span(start_byte, end_byte) {
            Some((start, end)) => {
                format_range(Lang::C, &text, assume_filename.as_deref(), None, start, end)
            }
            None => format_clang(&text, assume_filename.as_deref()),
        })
    }
}
