#[derive(Debug, Clone, thiserror::Error, uniffi::Error)]
pub enum EngineError {
    #[error("io {path}: {message}")]
    Io { path: String, message: String },
    #[error("metadata: {message}")]
    Metadata { message: String },
    #[error("index: {message}")]
    Index { message: String },
    #[error("session not found: {session_id}")]
    SessionNotFound { session_id: u64 },
    #[error("invalid edit: {message}")]
    InvalidEdit { message: String },
    #[error("panic: {message}")]
    Panic { message: String },
}

impl EngineError {
    pub fn io(path: impl AsRef<std::path::Path>, err: impl std::fmt::Display) -> Self {
        Self::Io {
            path: path.as_ref().display().to_string(),
            message: err.to_string(),
        }
    }

    pub fn from_panic(payload: Box<dyn std::any::Any + Send>) -> Self {
        let message = payload
            .downcast_ref::<&str>()
            .map(|s| (*s).to_string())
            .or_else(|| payload.downcast_ref::<String>().cloned())
            .unwrap_or_else(|| "panic".to_string());
        Self::Panic { message }
    }
}
