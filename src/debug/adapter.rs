use std::path::PathBuf;
use std::process::Command;

use super::transport::Transport;
use crate::error::EngineError;
use crate::toolchain::find_tool;

pub const ADAPTER: &str = "lldb-dap";

pub fn find_adapter() -> Option<PathBuf> {
    find_tool(ADAPTER).or_else(|| xcrun_path(ADAPTER))
}

pub fn adapter_path() -> Result<PathBuf, EngineError> {
    find_adapter().ok_or_else(|| EngineError::Tool {
        message: format!("{ADAPTER} not found: install Xcode or put {ADAPTER} on PATH"),
    })
}

pub fn spawn_adapter() -> Result<Transport, EngineError> {
    Transport::spawn(&adapter_path()?, &[])
}

fn xcrun_path(name: &str) -> Option<PathBuf> {
    let output = Command::new("/usr/bin/xcrun")
        .arg("-f")
        .arg(name)
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let path = PathBuf::from(String::from_utf8_lossy(&output.stdout).trim());
    path.is_file().then_some(path)
}
