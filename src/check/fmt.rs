use std::io::Write;
use std::process::{Command, Stdio};

use crate::error::EngineError;

pub fn format_source(text: &str, edition: Option<&str>) -> Result<String, EngineError> {
    let mut child = Command::new("rustfmt")
        .args(["--emit", "stdout", "--edition", edition.unwrap_or("2024")])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| EngineError::Tool {
            message: format!("rustfmt: {e}"),
        })?;
    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(text.as_bytes())
            .map_err(|e| EngineError::Tool {
                message: format!("rustfmt stdin: {e}"),
            })?;
    }
    let output = child.wait_with_output().map_err(|e| EngineError::Tool {
        message: format!("rustfmt: {e}"),
    })?;
    if !output.status.success() {
        return Err(EngineError::Tool {
            message: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}
