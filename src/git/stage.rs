use crate::error::EngineError;
use crate::ffi::{GitChangeKind, GitFileChange};

use super::cli::Git;
use super::repo::has_head;

pub fn stage(git: &Git, paths: &[String]) -> Result<(), EngineError> {
    with_paths(git, &["add", "--all"], paths)
}

pub fn unstage(git: &Git, paths: &[String]) -> Result<(), EngineError> {
    if has_head(git) {
        with_paths(git, &["restore", "--staged"], paths)
    } else {
        with_paths(git, &["rm", "--cached", "-r", "--quiet"], paths)
    }
}

pub fn discard(git: &Git, changes: &[GitFileChange]) -> Result<(), EngineError> {
    let (untracked, tracked): (Vec<_>, Vec<_>) = changes
        .iter()
        .filter(|c| c.unstaged.is_some())
        .partition(|c| c.unstaged == Some(GitChangeKind::Untracked));
    with_paths(git, &["restore", "--worktree"], &owned(&tracked))?;
    with_paths(git, &["clean", "--force", "--quiet"], &owned(&untracked))
}

fn owned(changes: &[&GitFileChange]) -> Vec<String> {
    changes.iter().map(|c| c.path.clone()).collect()
}

fn with_paths(git: &Git, verb: &[&str], paths: &[String]) -> Result<(), EngineError> {
    if paths.is_empty() {
        return Ok(());
    }
    let args: Vec<&str> = verb
        .iter()
        .copied()
        .chain(["--"])
        .chain(paths.iter().map(String::as_str))
        .collect();
    git.run(&args).map(|_| ())
}
