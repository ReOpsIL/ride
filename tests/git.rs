use std::fs;
use std::path::Path;
use std::process::Command;

use ride_engine::git::{
    Git, branches, checkout, commit, create_branch, discard, file_diff, last_message, pull, push,
    stage, status, unstage,
};
use ride_engine::{
    CaptureKind, GitChangeKind, GitDiffSide, GitFileChange, GitLineKind, GitRepoStatus,
};

fn sh(dir: &Path, args: &[&str]) {
    let ok = Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(args)
        .env("GIT_CONFIG_GLOBAL", "/dev/null")
        .output()
        .expect("git runs")
        .status
        .success();
    assert!(ok, "git {args:?}");
}

fn repo() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    sh(dir.path(), &["init", "--quiet", "--initial-branch=main"]);
    sh(dir.path(), &["config", "user.name", "Ride Test"]);
    sh(dir.path(), &["config", "user.email", "ride@example.com"]);
    sh(dir.path(), &["config", "commit.gpgsign", "false"]);
    dir
}

fn write(dir: &Path, name: &str, text: &str) {
    let path = dir.join(name);
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, text).unwrap();
}

fn current(dir: &Path) -> GitRepoStatus {
    status(dir).unwrap().expect("inside a repository")
}

fn change<'a>(status: &'a GitRepoStatus, path: &str) -> &'a GitFileChange {
    status.changes.iter().find(|c| c.path == path).unwrap()
}

fn committed(dir: &Path) -> Git {
    write(dir, "src/main.rs", "fn main() {\n    one();\n}\n");
    let git = Git::at(dir);
    stage(&git, &["src/main.rs".into()]).unwrap();
    commit(&git, "first", false).unwrap();
    git
}

#[test]
fn folders_outside_a_repository_have_no_status() {
    let dir = tempfile::tempdir().unwrap();
    assert!(status(dir.path()).unwrap().is_none());
}

#[test]
fn status_paths_are_relative_to_the_repository_root() {
    let dir = repo();
    committed(dir.path());
    write(dir.path(), "src/main.rs", "fn main() {}\n");
    write(dir.path(), "src/new.rs", "x\n");
    let st = current(&dir.path().join("src"));
    assert_eq!(st.branch.as_deref(), Some("main"));
    assert_eq!(
        change(&st, "src/main.rs").unstaged,
        Some(GitChangeKind::Modified)
    );
    assert_eq!(
        change(&st, "src/new.rs").unstaged,
        Some(GitChangeKind::Untracked)
    );
}

#[test]
fn stage_and_unstage_work_before_the_first_commit() {
    let dir = repo();
    let git = Git::at(dir.path());
    write(dir.path(), "a.rs", "a\n");
    stage(&git, &["a.rs".into()]).unwrap();
    assert_eq!(
        change(&current(dir.path()), "a.rs").staged,
        Some(GitChangeKind::Added)
    );
    unstage(&git, &["a.rs".into()]).unwrap();
    assert_eq!(
        change(&current(dir.path()), "a.rs").unstaged,
        Some(GitChangeKind::Untracked)
    );
}

#[test]
fn diffs_cover_unstaged_staged_and_untracked_sides() {
    let dir = repo();
    let git = committed(dir.path());
    write(dir.path(), "src/main.rs", "fn main() {\n    two();\n}\n");
    write(dir.path(), "notes.txt", "hello\nworld\n");
    let st = current(dir.path());
    let diff = file_diff(&git, change(&st, "src/main.rs"), GitDiffSide::Unstaged).unwrap();
    let kinds: Vec<_> = diff.hunks[0].lines.iter().map(|l| l.kind).collect();
    assert!(kinds.contains(&GitLineKind::Removed) && kinds.contains(&GitLineKind::Added));
    let fresh = file_diff(&git, change(&st, "notes.txt"), GitDiffSide::Unstaged).unwrap();
    assert_eq!(fresh.hunks[0].lines.len(), 2);
    assert_eq!(fresh.hunks[0].lines[1].new_line, Some(2));
    stage(&git, &["src/main.rs".into()]).unwrap();
    let st = current(dir.path());
    let staged = file_diff(&git, change(&st, "src/main.rs"), GitDiffSide::Staged).unwrap();
    assert_eq!(staged.hunks.len(), 1);
}

#[test]
fn commit_amend_and_last_message() {
    let dir = repo();
    let git = committed(dir.path());
    assert!(commit(&git, "  ", false).is_err());
    write(dir.path(), "b.rs", "b\n");
    stage(&git, &["b.rs".into()]).unwrap();
    commit(&git, "second\n\nbody", false).unwrap();
    assert_eq!(last_message(&git).unwrap(), "second\n\nbody");
    commit(&git, "second, reworded", true).unwrap();
    assert_eq!(last_message(&git).unwrap(), "second, reworded");
    assert!(current(dir.path()).changes.is_empty());
}

#[test]
fn discard_restores_tracked_and_removes_untracked_files() {
    let dir = repo();
    let git = committed(dir.path());
    write(dir.path(), "src/main.rs", "changed\n");
    write(dir.path(), "junk.txt", "junk\n");
    let st = current(dir.path());
    discard(&git, &st.changes).unwrap();
    assert!(current(dir.path()).changes.is_empty());
    assert!(!dir.path().join("junk.txt").exists());
}

#[test]
fn branches_create_switch_and_reject_bad_names() {
    let dir = repo();
    let git = committed(dir.path());
    create_branch(&git, "feature/x", true).unwrap();
    assert_eq!(current(dir.path()).branch.as_deref(), Some("feature/x"));
    assert!(create_branch(&git, "-f", false).is_err());
    assert!(create_branch(&git, "bad name", false).is_err());
    let all = branches(&git).unwrap();
    let main = all.iter().find(|b| b.name == "main").unwrap().clone();
    assert!(all.iter().any(|b| b.name == "feature/x" && b.current));
    checkout(&git, &main).unwrap();
    assert_eq!(current(dir.path()).branch.as_deref(), Some("main"));
}

#[test]
fn push_sets_the_upstream_and_pull_fast_forwards() {
    let remote = tempfile::tempdir().unwrap();
    sh(remote.path(), &["init", "--quiet", "--bare"]);
    let dir = repo();
    let git = committed(dir.path());
    let url = remote.path().display().to_string();
    sh(dir.path(), &["remote", "add", "origin", &url]);
    assert!(push(&git).is_ok());
    let st = current(dir.path());
    assert_eq!(st.upstream.as_deref(), Some("origin/main"));
    assert_eq!((st.ahead, st.behind), (0, 0));
    assert!(pull(&git).is_ok());
}

#[test]
fn push_without_a_remote_says_so() {
    let dir = repo();
    let git = committed(dir.path());
    let err = push(&git).unwrap_err().to_string();
    assert!(err.contains("no remote"), "{err}");
}

#[test]
fn diff_lines_carry_highlights_from_their_own_side() {
    let dir = repo();
    let git = committed(dir.path());
    write(
        dir.path(),
        "src/main.rs",
        "fn main() {\n    let two = 2;\n}\n",
    );
    write(dir.path(), "notes.txt", "fn not code\n");
    let st = current(dir.path());
    let diff = file_diff(&git, change(&st, "src/main.rs"), GitDiffSide::Unstaged).unwrap();
    let lines = &diff.hunks[0].lines;
    let added = lines.iter().find(|l| l.kind == GitLineKind::Added).unwrap();
    assert!(added.spans.iter().any(|s| s.capture == CaptureKind::Keyword
        && &added.text[s.start_byte as usize..s.end_byte as usize] == "let"));
    let removed = lines
        .iter()
        .find(|l| l.kind == GitLineKind::Removed)
        .unwrap();
    assert!(
        removed
            .spans
            .iter()
            .any(|s| s.capture == CaptureKind::Function)
    );
    let plain = file_diff(&git, change(&st, "notes.txt"), GitDiffSide::Unstaged).unwrap();
    assert!(plain.hunks[0].lines.iter().all(|l| l.spans.is_empty()));
}
