use crate::ffi::{GitChangeKind, GitDiffSide, GitFileChange};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Source {
    Head,
    Index,
    WorkTree,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DiffPlan {
    Untracked,
    Conflicted,
    WorkTree,
    Staged,
}

impl DiffPlan {
    pub fn of(change: &GitFileChange, side: GitDiffSide) -> Self {
        match (side, change.unstaged) {
            (GitDiffSide::Unstaged, Some(GitChangeKind::Untracked)) => Self::Untracked,
            (GitDiffSide::Unstaged, Some(GitChangeKind::Conflicted)) => Self::Conflicted,
            (GitDiffSide::Unstaged, _) => Self::WorkTree,
            (GitDiffSide::Staged, _) => Self::Staged,
        }
    }

    pub fn old_source(self) -> Option<Source> {
        match self {
            Self::Untracked => None,
            Self::Conflicted | Self::Staged => Some(Source::Head),
            Self::WorkTree => Some(Source::Index),
        }
    }

    pub fn new_source(self) -> Source {
        match self {
            Self::Staged => Source::Index,
            Self::Untracked | Self::Conflicted | Self::WorkTree => Source::WorkTree,
        }
    }
}
