use std::path::{Path, PathBuf};

pub struct IncludeRequest<'a> {
    pub quoted: bool,
    pub typed: &'a str,
    pub file: Option<&'a Path>,
    pub search_dirs: &'a [PathBuf],
    pub system_dirs: &'a [(PathBuf, bool)],
    pub limit: usize,
}

impl IncludeRequest<'_> {
    pub fn split_typed(&self) -> (&str, &str) {
        self.typed.rsplit_once('/').unwrap_or(("", self.typed))
    }
}
