use crate::error::EngineError;
use crate::ffi::{GitDiffSide, GitFileChange, GitFileDiff, GitLineKind};
use crate::highlight::Lang;

use super::blob;
use super::cli::Git;
use super::diff_parse::parse_diff;
use super::diff_plan::DiffPlan;
use super::line_spans::LineSpans;

const NO_INDEX_CODES: &[i32] = &[0, 1];
const BASE: [&str; 4] = ["diff", "--no-ext-diff", "--no-color", "-M"];

pub fn file_diff(
    git: &Git,
    change: &GitFileChange,
    side: GitDiffSide,
) -> Result<GitFileDiff, EngineError> {
    let plan = DiffPlan::of(change, side);
    let out = match plan {
        DiffPlan::Untracked => untracked(git, &change.path)?,
        DiffPlan::Conflicted => tracked(git, &["HEAD"], &[&change.path])?,
        DiffPlan::WorkTree => tracked(git, &[], &[&change.path])?,
        DiffPlan::Staged => tracked(git, &["--cached"], &paths(change))?,
    };
    let mut diff = parse_diff(&change.path, &out);
    if let Some(lang) = Lang::recognized(Some(&change.path)) {
        highlight(git, change, plan, lang, &mut diff);
    }
    Ok(diff)
}

fn highlight(
    git: &Git,
    change: &GitFileChange,
    plan: DiffPlan,
    lang: Lang,
    diff: &mut GitFileDiff,
) {
    if diff.binary || diff.hunks.is_empty() {
        return;
    }
    let old_path = change.orig_path.as_deref().unwrap_or(&change.path);
    let old = plan
        .old_source()
        .and_then(|source| blob::read(git, source, old_path))
        .map(|text| LineSpans::new(lang, &text))
        .unwrap_or_default();
    let new = blob::read(git, plan.new_source(), &change.path)
        .map(|text| LineSpans::new(lang, &text))
        .unwrap_or_default();
    for line in diff.hunks.iter_mut().flat_map(|h| h.lines.iter_mut()) {
        line.spans = match line.kind {
            GitLineKind::Removed => old.line(line.old_line),
            GitLineKind::Added | GitLineKind::Context => new.line(line.new_line),
        };
    }
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
