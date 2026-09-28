use std::path::PathBuf;

use crate::toolchain;

use super::error::OracleError;
use super::server::Server;

pub fn program(server: Server) -> Result<PathBuf, OracleError> {
    let missing = OracleError::NotInstalled {
        tool: server.name(),
        hint: server.hint(),
    };
    toolchain::find_runnable(server.name()).ok_or(missing)
}
