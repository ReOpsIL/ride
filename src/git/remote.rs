use std::time::Duration;

use crate::error::EngineError;

use super::cli::Git;

const REMOTE_IDLE: Duration = Duration::from_secs(60);

pub fn push(git: &Git) -> Result<String, EngineError> {
    let out = if has_upstream(git) {
        git.run_idle(&["push"], REMOTE_IDLE)?
    } else {
        let remote = default_remote(git)?;
        git.run_idle(&["push", "--set-upstream", &remote, "HEAD"], REMOTE_IDLE)?
    };
    Ok(out.transcript())
}

pub fn pull(git: &Git) -> Result<String, EngineError> {
    Ok(git
        .run_idle(&["pull", "--ff-only"], REMOTE_IDLE)?
        .transcript())
}

pub fn fetch(git: &Git) -> Result<String, EngineError> {
    Ok(git
        .run_idle(&["fetch", "--prune"], REMOTE_IDLE)?
        .transcript())
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
