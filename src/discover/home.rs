use std::path::PathBuf;

use crate::ffi::EngineConfig;

pub fn cargo_home(config: &EngineConfig) -> PathBuf {
    if let Some(path) = &config.cargo_home {
        return PathBuf::from(path);
    }
    if let Ok(path) = std::env::var("CARGO_HOME") {
        return PathBuf::from(path);
    }
    dirs_home().join(".cargo")
}

fn dirs_home() -> PathBuf {
    std::env::var_os("HOME")
        .or_else(|| std::env::var_os("USERPROFILE"))
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}
