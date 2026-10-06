use crate::error::EngineError;

use super::cli::Git;

pub fn push(git: &Git) -> Result<String, EngineError> {
    let out = if has_upstream(git) {
        git.run(&["push"])?
    } else {
        let remote = default_remote(git)?;
        git.run(&["push", "--set-upstream", &remote, "HEAD"])?
    };
    Ok(out.transcript())
}

pub fn pull(git: &Git) -> Result<String, EngineError> {
    Ok(git.run(&["pull", "--ff-only"])?.transcript())
}

pub fn fetch(git: &Git) -> Result<String, EngineError> {
    Ok(git.run(&["fetch", "--prune"])?.transcript())
}

fn has_upstream(git: &Git) -> bool {
    git.succeeds(&[
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
    ])
}

fn default_remote(git: &Git) -> Result<String, EngineError> {
    let out = git.run(&["remote"])?;
    let remotes: Vec<&str> = out
        .stdout
        .lines()
        .map(str::trim)
        .filter(|r| !r.is_empty())
        .collect();
    remotes
        .iter()
        .find(|r| **r == "origin")
        .or_else(|| remotes.first())
        .map(|r| r.to_string())
        .ok_or_else(|| EngineError::git("no remote is configured; add one with git remote add"))
}
