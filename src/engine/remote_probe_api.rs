use crate::error::EngineError;
use crate::ffi::{RemoteCheck, RemoteCheckStatus, RemoteCommand, RemoteLink};
use crate::remote::{self, Check, Status};

use super::Engine;
use super::remote_api::{as_remote, command};

#[uniffi::export]
impl Engine {
    pub fn remote_probe(&self, link: RemoteLink) -> Result<RemoteCommand, EngineError> {
        remote::from_link(&link)
            .and_then(|endpoint| endpoint.probe())
            .map(command)
            .map_err(as_remote)
    }

    pub fn remote_probe_report(
        &self,
        link: RemoteLink,
        output: String,
    ) -> Result<Vec<RemoteCheck>, EngineError> {
        let endpoint = remote::from_link(&link).map_err(as_remote)?;
        Ok(remote::read_probe(&endpoint, &output)
            .into_iter()
            .map(check)
            .collect())
    }
}

fn check(check: Check) -> RemoteCheck {
    RemoteCheck {
        title: check.title,
        status: match check.status {
            Status::Pass => RemoteCheckStatus::Pass,
            Status::Warn => RemoteCheckStatus::Warn,
            Status::Fail => RemoteCheckStatus::Fail,
        },
        detail: check.detail,
    }
}
