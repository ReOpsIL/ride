use std::fs;
use std::path::Path;

use crate::error::EngineError;
use crate::follow::{self, Mark};
use crate::git::{self, Git};

use super::inbox::review_files;
use super::model::{Candidate, FileInput, Inbox};
use super::patch::{self, PatchFile};

const LIMIT: usize = 1_000_000;

pub fn load(root: &Path) -> Result<(Inbox, Vec<Mark>, Vec<Candidate>), EngineError> {
    let git = git::require(root)?;
    load_at(&git, None)
}

pub fn load_at(
    git: &Git,
    base_override: Option<&str>,
) -> Result<(Inbox, Vec<Mark>, Vec<Candidate>), EngineError> {
    let base = match base_override {
        Some(base) => base.to_string(),
        None => git::merge_base(git)?,
    };
    let head = git::head_commit(git).unwrap_or_default();
    let upstream = git::upstream_name(git);
    let diff = git.run(&["diff", "-U0", "--find-renames", &base])?.stdout;
    let untracked = git
        .run(&["ls-files", "--others", "--exclude-standard"])?
        .stdout;
    let mut inputs = inputs(git, &base, &patch::parse(&diff));
    for path in untracked
        .lines()
        .map(str::trim)
        .filter(|path| !path.is_empty())
    {
        if inputs.iter().any(|file| file.path == path) {
            continue;
        }
        inputs.push(untracked_file(git, path));
    }
    let seen: Vec<String> = inputs.iter().map(|file| file.path.clone()).collect();
    let mut built = review_files(&inputs);
    built.inbox.base = base;
    built.inbox.head = head;
    built.inbox.upstream = upstream;
    let marks = follow::read_all(git.dir());
    let mut items = built.items;
    for mark in &marks {
        if items.iter().any(|item| item.path == mark.path)
            || seen.iter().any(|path| path == &mark.path)
        {
            continue;
        }
        if let Ok(text) = fs::read_to_string(git.dir().join(&mark.path)) {
            items.extend(index_text(&mark.path, &text));
        }
    }
    follow::attach(&mut built.inbox, &marks, &items);
    Ok((built.inbox, marks, items))
}

pub fn index_text(path: &str, text: &str) -> Vec<Candidate> {
    let built = review_files(&[FileInput {
        path: path.to_string(),
        old_text: None,
        new_text: Some(text.to_string()),
        binary: false,
        hunks: None,
    }]);
    built.items
}

fn inputs(git: &Git, base: &str, files: &[PatchFile]) -> Vec<FileInput> {
    files
        .iter()
        .filter(|file| !super::model::skipped(&file.path))
        .map(|file| input(git, base, file))
        .collect()
}

fn input(git: &Git, base: &str, file: &PatchFile) -> FileInput {
    let old_path = file.old_path.as_deref().unwrap_or(&file.path);
    let old_text = if file.added || file.binary {
        None
    } else {
        read_rev(git, base, old_path)
    };
    let new_text = if file.deleted || file.binary {
        None
    } else {
        read_work(git, &file.path)
    };
    let hunks = if file.hunks.old.is_empty() && file.hunks.new.is_empty() {
        None
    } else {
        Some(file.hunks.clone())
    };
    FileInput {
        path: file.path.clone(),
        old_text,
        new_text,
        binary: file.binary,
        hunks,
    }
}

fn untracked_file(git: &Git, path: &str) -> FileInput {
    FileInput {
        path: path.to_string(),
        old_text: None,
        new_text: read_work(git, path),
        binary: false,
        hunks: None,
    }
}

fn read_rev(git: &Git, rev: &str, path: &str) -> Option<String> {
    let text = git::blob_at(git, rev, path)?;
    (text.len() <= LIMIT && !text.contains('\0')).then_some(text)
}

fn read_work(git: &Git, path: &str) -> Option<String> {
    let bytes = fs::read(git.dir().join(path)).ok()?;
    if bytes.len() > LIMIT || bytes.contains(&0) {
        return None;
    }
    String::from_utf8(bytes).ok()
}
