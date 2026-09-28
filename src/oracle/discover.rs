use std::path::PathBuf;
use std::process::Command;

use crate::toolchain;

use super::error::OracleError;
use super::server::Server;

pub fn program(server: Server) -> Result<PathBuf, OracleError> {
    let missing = OracleError::NotInstalled {
        tool: server.name(),
        hint: server.hint(),
    };
    let Some(path) = toolchain::find_tool(server.name()) else {
        return Err(missing);
    };
    let runs = Command::new(&path)
        .arg("--version")
        .env("PATH", toolchain::search_path())
        .output()
        .is_ok_and(|out| out.status.success());
    runs.then_some(path).ok_or(missing)
}
