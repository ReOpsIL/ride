use std::path::Path;
use std::process::Command;

use crate::error::EngineError;
use crate::ffi::CheckResult;

use super::parse::parse_lines;

const STDERR_TAIL: usize = 2000;

pub fn run_check(root: &Path, target_dir: Option<&Path>) -> Result<CheckResult, EngineError> {
    let mut cmd = Command::new("cargo");
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
        stderr_tail: tail(&stderr),
    })
}

fn tail(text: &str) -> String {
    let start = text.len().saturating_sub(STDERR_TAIL);
    let mut idx = start;
    while !text.is_char_boundary(idx) {
        idx += 1;
    }
    text[idx..].to_string()
}
