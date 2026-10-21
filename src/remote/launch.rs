use crate::ffi::DebugLaunch;

use super::argv;
use super::endpoint::Endpoint;
use super::error::RemoteError;

pub fn map_launch(
    endpoint: &Endpoint,
    mut launch: DebugLaunch,
) -> Result<DebugLaunch, RemoteError> {
    launch.program = argv::prepare_arg(endpoint, &launch.program)?;
    launch.args = launch
        .args
        .iter()
        .map(|arg| argv::prepare_arg(endpoint, arg))
        .collect::<Result<Vec<_>, _>>()?;
    if let Some(cwd) = launch.cwd {
        launch.cwd = Some(argv::prepare_arg(endpoint, &cwd)?);
    }
    Ok(launch)
}
