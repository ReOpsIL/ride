use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::{Path, PathBuf};

use crate::check::{parse_clang, parse_message_line};
use crate::ffi::Diagnostic;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn parse_cargo_line(&self, line: String, project_root: String) -> Vec<Diagnostic> {
        let root = self.cargo_root(Path::new(&project_root));
        catch_unwind(AssertUnwindSafe(|| parse_message_line(&root, &line))).unwrap_or_default()
    }

    pub fn parse_clang_output(&self, text: String, base_dir: String) -> Vec<Diagnostic> {
        let base = PathBuf::from(base_dir);
        catch_unwind(AssertUnwindSafe(|| parse_clang(&text, &base))).unwrap_or_default()
    }
}

impl Engine {
    pub(crate) fn cargo_root(&self, project: &Path) -> PathBuf {
        if let Ok(Some(root)) = self.read(|i| i.cargo_roots.get(project).cloned()) {
            return root;
        }
        let root =
            crate::discover::cargo_workspace_root(project).unwrap_or_else(|| project.to_path_buf());
        let _ = self.write(|i| {
            i.cargo_roots.insert(project.to_path_buf(), root.clone());
        });
        root
    }

    pub(crate) fn forget_cargo_roots(&self) {
        let _ = self.write(|i| i.cargo_roots.clear());
    }
}
