use std::path::Path;
use std::process::Command;

use crate::error::EngineError;
use crate::ffi::DebugProcess;

const PS: &str = "/bin/ps";

pub fn list_processes() -> Result<Vec<DebugProcess>, EngineError> {
    let output = Command::new(PS)
        .args(["-x", "-o", "pid=", "-o", "ppid=", "-o", "comm="])
        .output()
        .map_err(|err| EngineError::Tool {
            message: format!("{PS}: {err}"),
        })?;
    if !output.status.success() {
        return Err(EngineError::Tool {
            message: format!("{PS}: {}", String::from_utf8_lossy(&output.stderr).trim()),
        });
    }
    Ok(parse_processes(&String::from_utf8_lossy(&output.stdout)))
}

pub fn parse_processes(listing: &str) -> Vec<DebugProcess> {
    let mut processes: Vec<DebugProcess> = listing.lines().filter_map(parse_row).collect();
    processes.sort_by(|left, right| right.pid.cmp(&left.pid));
    processes
}

fn parse_row(row: &str) -> Option<DebugProcess> {
    let (pid, rest) = row.trim_start().split_once(char::is_whitespace)?;
    let (parent, path) = rest.trim_start().split_once(char::is_whitespace)?;
    let path = path.trim();
    let name = Path::new(path).file_name()?.to_string_lossy().to_string();
    Some(DebugProcess {
        pid: pid.parse().ok()?,
        parent: parent.parse().ok()?,
        name,
        path: path.to_string(),
    })
}
