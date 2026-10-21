use std::path::Path;

use crate::ffi::{RemoteLink, RemoteReach};

use super::endpoint::Endpoint;
use super::error::RemoteError;

pub fn from_link(link: &RemoteLink) -> Result<Endpoint, RemoteError> {
    let identity = optional(&link.identity).map(Path::new);
    let local = Path::new(&link.local_root);
    let remote = Path::new(&link.remote_root);
    match link.kind {
        RemoteReach::Vm => Endpoint::vm(&link.user, &link.host, link.port, identity, local, remote),
        RemoteReach::Container => Endpoint::container(
            &link.user,
            &link.host,
            link.port,
            identity,
            optional(&link.proxy_command),
            local,
            remote,
        ),
        RemoteReach::Docker => Endpoint::docker(&link.name, &link.user, identity, local, remote),
        RemoteReach::Pod => Endpoint::pod(
            &link.namespace,
            &link.name,
            optional(&link.container),
            &link.user,
            identity,
            local,
            remote,
        ),
    }
}

fn optional(value: &str) -> Option<&str> {
    if value.is_empty() { None } else { Some(value) }
}
