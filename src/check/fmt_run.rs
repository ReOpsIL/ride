use std::ffi::OsStr;
use std::process::{Command, Stdio};

use crate::error::EngineError;
use crate::process::run_piped;
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
    cmd.stdout(Stdio::piped()).stderr(Stdio::piped());
    let output = run_piped(&mut cmd, name, text)?;
    if !output.status.success() {
        return Err(EngineError::Tool {
            message: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}
