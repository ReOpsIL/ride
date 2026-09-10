use std::io::Write;
use std::process::{Command, Stdio};

use crate::error::EngineError;

pub fn format_source(text: &str, edition: Option<&str>) -> Result<String, EngineError> {
    let mut cmd = crate::toolchain::tool("rustfmt");
    cmd.args(["--emit", "stdout", "--edition", edition.unwrap_or("2024")]);
    pipe(cmd, "rustfmt", text)
}

pub fn format_clang(text: &str, assume_filename: Option<&str>) -> Result<String, EngineError> {
    let mut cmd = crate::toolchain::tool("clang-format");
    if let Some(name) = assume_filename {
        cmd.arg(format!("--assume-filename={name}"));
    }
    pipe(cmd, "clang-format", text)
}

fn pipe(mut cmd: Command, name: &str, text: &str) -> Result<String, EngineError> {
    let mut child = cmd
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| EngineError::Tool {
            message: format!("{name}: {e}"),
        })?;
    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(text.as_bytes())
            .map_err(|e| EngineError::Tool {
                message: format!("{name} stdin: {e}"),
            })?;
    }
    let output = child.wait_with_output().map_err(|e| EngineError::Tool {
        message: format!("{name}: {e}"),
    })?;
    if !output.status.success() {
        return Err(EngineError::Tool {
            message: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}
