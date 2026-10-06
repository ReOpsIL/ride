use super::session::HighlightSpan;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum GitChangeKind {
    Modified,
    TypeChanged,
    Added,
    Deleted,
    Renamed,
    Copied,
    Untracked,
    Conflicted,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum GitDiffSide {
    Staged,
    Unstaged,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct GitFileChange {
    pub path: String,
    pub orig_path: Option<String>,
    pub staged: Option<GitChangeKind>,
    pub unstaged: Option<GitChangeKind>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct GitRepoStatus {
    pub root: String,
    pub branch: Option<String>,
    pub head: Option<String>,
    pub upstream: Option<String>,
    pub ahead: u32,
    pub behind: u32,
    pub changes: Vec<GitFileChange>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum GitLineKind {
    Context,
    Added,
    Removed,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct GitDiffLine {
    pub kind: GitLineKind,
    pub old_line: Option<u32>,
    pub new_line: Option<u32>,
    pub text: String,
    pub spans: Vec<HighlightSpan>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct GitHunk {
    pub header: String,
    pub old_start: u32,
    pub old_count: u32,
    pub new_start: u32,
    pub new_count: u32,
    pub lines: Vec<GitDiffLine>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct GitFileDiff {
    pub path: String,
    pub binary: bool,
    pub hunks: Vec<GitHunk>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct GitBranch {
    pub name: String,
    pub remote: bool,
    pub current: bool,
    pub upstream: Option<String>,
}
