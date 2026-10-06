use crate::error::EngineError;

use super::cli::Git;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BranchName(String);

impl BranchName {
    pub fn parse(git: &Git, raw: &str) -> Result<Self, EngineError> {
        let name = raw.trim();
        if name.is_empty() || name.starts_with('-') {
            return Err(invalid(name));
        }
        git.run(&["check-ref-format", "--branch", name])
            .map(|_| Self(name.to_string()))
            .map_err(|_| invalid(name))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

fn invalid(name: &str) -> EngineError {
    EngineError::git(format!("'{name}' is not a valid branch name"))
}
