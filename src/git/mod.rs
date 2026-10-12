mod blob;
mod branch;
mod branch_name;
mod cli;
mod commit;
mod diff;
mod diff_parse;
mod diff_plan;
mod line_spans;
mod merge_base;
mod remote;
mod repo;
mod stage;
mod status_parse;

pub use blob::{at as blob_at, read as read_blob};
pub use branch::{branches, checkout, create as create_branch};
pub use cli::Git;
pub use commit::{commit, last_message};
pub use diff::file_diff;
pub use merge_base::{
    base as merge_base, head as head_commit, upstream as upstream_name, user_name,
};
pub use remote::{fetch, pull, push};
pub use repo::{require, status};
pub use stage::{discard, stage, unstage};
