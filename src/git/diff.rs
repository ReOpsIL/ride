use crate::error::EngineError;
use crate::ffi::{GitChangeKind, GitDiffSide, GitFileChange, GitFileDiff};

use super::cli::Git;
use super::diff_parse::parse_diff;

const NO_INDEX_CODES: &[i32] = &[0, 1];
const BASE: [&str; 4] = ["diff", "--no-ext-diff", "--no-color", "-M"];

pub fn file_diff(
    git: &Git,
    change: &GitFileChange,
    side: GitDiffSide,
) -> Result<GitFileDiff, EngineError> {
    let out = match (side, change.unstaged) {
        (GitDiffSide::Unstaged, Some(GitChangeKind::Untracked)) => untracked(git, &change.path)?,
        (GitDiffSide::Unstaged, Some(GitChangeKind::Conflicted)) => {
            tracked(git, &["HEAD"], &[&change.path])?
        }
        (GitDiffSide::Unstaged, _) => tracked(git, &[], &[&change.path])?,
        (GitDiffSide::Staged, _) => tracked(git, &["--cached"], &paths(change))?,
    };
    Ok(parse_diff(&change.path, &out))
}

fn paths(change: &GitFileChange) -> Vec<&str> {
    change
        .orig_path
        .as_deref()
        .into_iter()
        .chain([change.path.as_str()])
        .collect()
}

fn tracked(git: &Git, revision: &[&str], paths: &[&str]) -> Result<String, EngineError> {
    let args: Vec<&str> = BASE
        .iter()
        .copied()
        .chain(revision.iter().copied())
        .chain(["--"])
        .chain(paths.iter().copied())
        .collect();
    Ok(git.run(&args)?.stdout)
}

fn untracked(git: &Git, path: &str) -> Result<String, EngineError> {
    let args = [
        "diff",
        "--no-ext-diff",
        "--no-color",
        "--no-index",
        "--",
        "/dev/null",
        path,
    ];
    Ok(git.run_accepting(&args, NO_INDEX_CODES)?.stdout)
}
