use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{GitBranch, GitDiffSide, GitFileChange, GitFileDiff, GitRepoStatus};
use crate::git::{self, Git};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn git_status(&self, root: String) -> Result<Option<GitRepoStatus>, EngineError> {
        self.guard(|| git::status(Path::new(&root)))
    }

    pub fn git_diff(
        &self,
        root: String,
        change: GitFileChange,
        side: GitDiffSide,
    ) -> Result<GitFileDiff, EngineError> {
        self.in_repo(&root, |g| git::file_diff(g, &change, side))
    }

    pub fn git_branches(&self, root: String) -> Result<Vec<GitBranch>, EngineError> {
        self.in_repo(&root, git::branches)
    }

    pub fn git_last_message(&self, root: String) -> Result<String, EngineError> {
        self.in_repo(&root, git::last_message)
    }
}

impl Engine {
    pub(super) fn in_repo<T>(
        &self,
        root: &str,
        op: impl FnOnce(&Git) -> Result<T, EngineError>,
    ) -> Result<T, EngineError> {
        self.guard(|| op(&git::require(Path::new(root))?))
    }
}
