use crate::wire::{FrameError, MailboxError};

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OracleError {
    #[error("{tool} not found ({hint})")]
    NotInstalled {
        tool: &'static str,
        hint: &'static str,
    },
    #[error("spawn rust-analyzer: {0}")]
    Spawn(String),
    #[error(transparent)]
    Frame(#[from] FrameError),
    #[error("{method}: {source}")]
    Reply {
        method: String,
        source: MailboxError,
    },
    #[error("{method}: {message}")]
    Server { method: String, message: String },
    #[error("language server keeps exiting: {0}")]
    GaveUp(String),
}
