use std::ffi::OsStr;
use std::io::Write;
use std::process::{Command, Stdio};

use crate::error::EngineError;
use crate::toolchain::{find_tool, install_hint};

pub fn run<I, S>(name: &str, args: I, text: &str) -> Result<String, EngineError>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let Some(path) = find_tool(name) else {
        return Err(EngineError::Tool {
            message: format!("{name} is not installed: {}", install_hint(name)),
        });
    };
    let mut cmd = Command::new(path);
    cmd.args(args);
    pipe(cmd, name, text)
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
