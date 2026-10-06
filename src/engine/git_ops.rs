use crate::error::EngineError;
use crate::ffi::{GitBranch, GitFileChange};
use crate::git;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn git_stage(&self, root: String, paths: Vec<String>) -> Result<(), EngineError> {
        self.in_repo(&root, |g| git::stage(g, &paths))
    }

    pub fn git_unstage(&self, root: String, paths: Vec<String>) -> Result<(), EngineError> {
        self.in_repo(&root, |g| git::unstage(g, &paths))
    }

    pub fn git_discard(
        &self,
        root: String,
        changes: Vec<GitFileChange>,
    ) -> Result<(), EngineError> {
        self.in_repo(&root, |g| git::discard(g, &changes))
    }

    pub fn git_commit(
        &self,
        root: String,
        message: String,
        amend: bool,
    ) -> Result<String, EngineError> {
        self.in_repo(&root, |g| git::commit(g, &message, amend))
    }

    pub fn git_create_branch(
        &self,
        root: String,
        name: String,
        checkout: bool,
    ) -> Result<(), EngineError> {
        self.in_repo(&root, |g| git::create_branch(g, &name, checkout))
    }

    pub fn git_checkout(&self, root: String, branch: GitBranch) -> Result<(), EngineError> {
        self.in_repo(&root, |g| git::checkout(g, &branch))
    }

    pub fn git_push(&self, root: String) -> Result<String, EngineError> {
        self.in_repo(&root, git::push)
    }

    pub fn git_pull(&self, root: String) -> Result<String, EngineError> {
        self.in_repo(&root, git::pull)
    }

    pub fn git_fetch(&self, root: String) -> Result<String, EngineError> {
        self.in_repo(&root, git::fetch)
    }
}
