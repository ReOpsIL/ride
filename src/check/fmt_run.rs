use std::ffi::OsStr;
use std::path::Path;
use std::process::{Command, Stdio};

use crate::error::EngineError;
use crate::process::run_piped;
use crate::toolchain::{find_tool, install_hint};

pub fn run<I, S>(name: &str, args: I, text: &str, file: Option<&str>) -> Result<String, EngineError>
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
    if let Some(dir) = working_dir(file) {
        cmd.current_dir(dir);
    }
    pipe(cmd, name, text)
}

fn working_dir(file: Option<&str>) -> Option<&Path> {
    Path::new(file?).parent().filter(|dir| dir.is_dir())
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
