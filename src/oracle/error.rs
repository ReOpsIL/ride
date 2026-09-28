use crate::wire::{FrameError, MailboxError};

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OracleError {
    #[error("rust-analyzer not found (rustup component add rust-analyzer)")]
    NotInstalled,
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
    #[error("rust-analyzer keeps exiting: {0}")]
    GaveUp(String),
}
