use std::path::Path;

use crate::error::EngineError;
use crate::ffi::CheckResult;

use super::output::stderr_tail;
use super::parse::parse_lines;

pub fn run_check(root: &Path, target_dir: Option<&Path>) -> Result<CheckResult, EngineError> {
    let mut cmd = crate::toolchain::tool("cargo");
    cmd.args(["check", "--message-format=json", "--color", "never"])
        .current_dir(root);
    if let Some(dir) = target_dir {
        cmd.env("CARGO_TARGET_DIR", dir);
    }
    let output = cmd.output().map_err(|e| EngineError::Tool {
        message: format!("cargo check: {e}"),
    })?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    Ok(CheckResult {
        success: output.status.success(),
        diagnostics: parse_lines(root, &stdout),
        stderr_tail: stderr_tail(&stderr),
    })
}
