use std::path::Path;

use crate::error::EngineError;
use crate::ffi::GitRepoStatus;

use super::cli::Git;
use super::status_parse::parse_status;

pub fn open(dir: &Path) -> Option<Git> {
    let probe = Git::at(dir);
    let top = probe.run(&["rev-parse", "--show-toplevel"]).ok()?;
    let top = top.stdout.trim();
    (!top.is_empty()).then(|| Git::at(top))
}

pub fn status(dir: &Path) -> Result<Option<GitRepoStatus>, EngineError> {
    let Some(git) = open(dir) else {
        return Ok(None);
    };
    let out = git.run(&[
        "status",
        "--porcelain=v2",
        "--branch",
        "-z",
        "--untracked-files=all",
    ])?;
    let root = git.dir().display().to_string();
    Ok(Some(parse_status(&root, &out.stdout)))
}

pub fn has_head(git: &Git) -> bool {
    git.succeeds(&["rev-parse", "--verify", "--quiet", "HEAD"])
}

pub fn require(dir: &Path) -> Result<Git, EngineError> {
    open(dir).ok_or_else(|| {
        EngineError::git(format!("{} is not inside a git repository", dir.display()))
    })
}
