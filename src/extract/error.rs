use std::path::PathBuf;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum ExtractError {
    #[error("io {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("parse {path}: {message}")]
    Parse { path: PathBuf, message: String },
    #[error("language: {0}")]
    Language(String),
    #[error("toml {path}: {message}")]
    Toml { path: PathBuf, message: String },
}
