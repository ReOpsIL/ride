use std::path::PathBuf;
use std::process::Command;

use crate::toolchain;

use super::error::OracleError;

pub fn rust_analyzer() -> Result<PathBuf, OracleError> {
    let path = toolchain::find_tool("rust-analyzer").ok_or(OracleError::NotInstalled)?;
    let runs = Command::new(&path)
        .arg("--version")
        .env("PATH", toolchain::search_path())
        .output()
        .is_ok_and(|out| out.status.success());
    runs.then_some(path).ok_or(OracleError::NotInstalled)
}
