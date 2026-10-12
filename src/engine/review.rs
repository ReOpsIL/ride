use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{ReviewDossier, ReviewHunt, ReviewInbox, ReviewMark};
use crate::follow::{self, Mark};
use crate::git::{self, Git};
use crate::review;

use super::Engine;
use super::review_map::{dossier_view, failing_line, hunt, inbox_view, trail_dir};

#[uniffi::export]
impl Engine {
    pub fn review_inbox(&self, root: String) -> Result<ReviewInbox, EngineError> {
        self.guard(|| {
            let (inbox, _, _) = review::load_repo(Path::new(&root))?;
            Ok(inbox_view(inbox))
        })
    }

    pub fn review_mark(&self, root: String, mark: ReviewMark) -> Result<(), EngineError> {
        self.guard(|| write_mark(&root, mark))
    }

    pub fn review_drop(&self, root: String, id: String) -> Result<(), EngineError> {
        self.guard(|| drop_mark(&root, &id))
    }

    pub fn review_dossier(
        &self,
        root: String,
        path: String,
        item: String,
    ) -> Result<ReviewDossier, EngineError> {
        self.guard(|| {
            let git = git::require(Path::new(&root))?;
            let (inbox, marks, _) = review::load_repo(git.dir())?;
            let row = inbox
                .rows
                .iter()
                .find(|row| row.path == path && row.item == item)
                .cloned()
                .ok_or_else(|| EngineError::git("item is not in this review"))?;
            let author = follow::slug(&git::user_name(&git)).unwrap_or_default();
            Ok(dossier_view(review::dossier(
                &git,
                &row,
                &marks,
                &inbox.base,
                &author,
            )))
        })
    }

    pub fn review_summary(&self, root: String) -> Result<String, EngineError> {
        self.guard(|| {
            let (inbox, _, _) = review::load_repo(Path::new(&root))?;
            Ok(review::summary(&inbox))
        })
    }

    pub fn review_brief(&self, root: String) -> Result<String, EngineError> {
        self.guard(|| {
            let (inbox, marks, _) = review::load_repo(Path::new(&root))?;
            let failing = failing_line(self, &root);
            Ok(review::brief(&inbox, &marks, failing.as_deref()))
        })
    }

    pub fn review_hunt(&self, root: String) -> Result<Vec<ReviewHunt>, EngineError> {
        self.guard(|| hunt(self, &root))
    }

    pub fn review_trail(
        &self,
        root: String,
        kind: String,
        name: String,
        path: String,
        passed: bool,
        note: String,
    ) -> Result<(), EngineError> {
        self.guard(|| {
            let dir = trail_dir(self)?;
            crate::trail::append(&dir, &root, &kind, &name, &path, passed, &note)
        })
    }
}

fn write_mark(root: &str, mark: ReviewMark) -> Result<(), EngineError> {
    let git = git::require(Path::new(root))?;
    let author = author(&git)?;
    let commit = git::head_commit(&git).unwrap_or_default();
    follow::upsert(
        Path::new(root),
        &author,
        false,
        Mark {
            id: follow::new_id(),
            author: author.clone(),
            agent: false,
            path: mark.path,
            item: mark.item,
            kind: mark.kind,
            mark: mark.mark,
            note: mark.note,
            basis: mark.basis,
            commit,
            at: String::new(),
            re: String::new(),
            accepted: false,
        },
    )
}

fn drop_mark(root: &str, id: &str) -> Result<(), EngineError> {
    let git = git::require(Path::new(root))?;
    let author = author(&git)?;
    follow::drop(Path::new(root), &author, id)
}

fn author(git: &Git) -> Result<String, EngineError> {
    follow::slug(&git::user_name(git)).ok_or_else(|| EngineError::git("git user.name is empty"))
}
