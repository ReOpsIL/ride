use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::{Path, PathBuf};

use crate::check::{parse_clang, parse_message_line};
use crate::ffi::Diagnostic;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn parse_cargo_line(&self, line: String) -> Vec<Diagnostic> {
        let root = self.cargo_root(None);
        catch_unwind(AssertUnwindSafe(|| parse_message_line(&root, &line))).unwrap_or_default()
    }

    pub fn parse_clang_output(&self, text: String, base_dir: String) -> Vec<Diagnostic> {
        let base = PathBuf::from(base_dir);
        catch_unwind(AssertUnwindSafe(|| parse_clang(&text, &base))).unwrap_or_default()
    }
}

impl Engine {
    pub(crate) fn cargo_root(&self, project: Option<&Path>) -> PathBuf {
        let workspace = self
            .read(|i| {
                i.workspace
                    .as_ref()
                    .map(|w| (PathBuf::from(&w.root), PathBuf::from(&w.workspace_root)))
            })
            .ok()
            .flatten();
        match (workspace, project) {
            (Some((_, workspace_root)), None) => workspace_root,
            (Some((root, workspace_root)), Some(project))
                if project.starts_with(&root) || project.starts_with(&workspace_root) =>
            {
                workspace_root
            }
            (_, Some(project)) => project.to_path_buf(),
            (None, None) => PathBuf::new(),
        }
    }
}
