use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Default)]
pub struct Roots {
    by_dir: HashMap<PathBuf, Option<PathBuf>>,
}

impl Roots {
    pub fn of(&mut self, file: &Path) -> Option<PathBuf> {
        let dir = file.parent()?;
        self.by_dir
            .entry(dir.to_path_buf())
            .or_insert_with(|| crate::discover::cargo_workspace_root(dir))
            .clone()
    }
}
