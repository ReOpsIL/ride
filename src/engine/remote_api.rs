use std::collections::HashMap;
use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{RemoteCommand, RemoteLink, RemoteSync};
use crate::remote::{self, Invocation};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn remote_command(
        &self,
        link: RemoteLink,
        cwd: String,
        env: HashMap<String, String>,
        argv: Vec<String>,
    ) -> Result<RemoteCommand, EngineError> {
        let endpoint = remote::from_link(&link).map_err(as_remote)?;
        let owned: Vec<(String, String)> = env.into_iter().collect();
        let pairs: Vec<(&str, &str)> = owned
            .iter()
            .map(|(key, value)| (key.as_str(), value.as_str()))
            .collect();
        let args: Vec<&str> = argv.iter().map(String::as_str).collect();
        let invocation = endpoint
            .invocation(Path::new(&cwd), &pairs, &args)
            .map_err(as_remote)?;
        Ok(command(invocation))
    }

    pub fn remote_sync(&self, link: RemoteLink) -> Result<RemoteSync, EngineError> {
        let job = remote::from_link(&link)
            .and_then(|endpoint| endpoint.sync())
            .map_err(as_remote)?;
        Ok(RemoteSync {
            pack: command(job.pack),
            unpack: command(job.unpack),
        })
    }
}

pub(super) fn command(invocation: Invocation) -> RemoteCommand {
    RemoteCommand {
        program: invocation.program,
        args: invocation.args,
    }
}

pub(super) fn as_remote(err: remote::RemoteError) -> EngineError {
    EngineError::remote(err.to_string())
}
