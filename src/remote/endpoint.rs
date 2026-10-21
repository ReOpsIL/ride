use std::path::{Path, PathBuf};

use super::check;
use super::error::RemoteError;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Reach {
    Vm,
    Container,
    Pod,
    Docker,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Endpoint {
    reach: Reach,
    user: String,
    host: String,
    port: u16,
    identity: Option<PathBuf>,
    proxy_command: Option<String>,
    local_root: PathBuf,
    remote_root: PathBuf,
}

impl Endpoint {
    pub fn vm(
        user: &str,
        host: &str,
        port: u16,
        identity: Option<&Path>,
        local_root: &Path,
        remote_root: &Path,
    ) -> Result<Self, RemoteError> {
        Self::open(Spec {
            reach: Reach::Vm,
            user,
            host,
            port,
            identity,
            proxy_command: None,
            local_root,
            remote_root,
        })
    }

    pub fn container(
        user: &str,
        host: &str,
        port: u16,
        identity: Option<&Path>,
        proxy_command: Option<&str>,
        local_root: &Path,
        remote_root: &Path,
    ) -> Result<Self, RemoteError> {
        let proxy = match proxy_command {
            Some(command) => {
                check::proxy(command)?;
                Some(command.to_string())
            }
            None => None,
        };
        Self::open(Spec {
            reach: Reach::Container,
            user,
            host,
            port,
            identity,
            proxy_command: proxy,
            local_root,
            remote_root,
        })
    }

    pub fn docker(
        container: &str,
        user: &str,
        identity: Option<&Path>,
        local_root: &Path,
        remote_root: &Path,
    ) -> Result<Self, RemoteError> {
        let name = check::token(container)?;
        Self::open(Spec {
            reach: Reach::Docker,
            user,
            host: "127.0.0.1",
            port: 22,
            identity,
            proxy_command: Some(format!("docker exec -i {name} nc %h %p")),
            local_root,
            remote_root,
        })
    }

    pub fn pod(
        namespace: &str,
        pod: &str,
        container: Option<&str>,
        user: &str,
        identity: Option<&Path>,
        local_root: &Path,
        remote_root: &Path,
    ) -> Result<Self, RemoteError> {
        let namespace = check::token(namespace)?;
        let pod = check::token(pod)?;
        let proxy = pod_proxy(&namespace, &pod, container)?;
        Self::open(Spec {
            reach: Reach::Pod,
            user,
            host: "127.0.0.1",
            port: 22,
            identity,
            proxy_command: Some(proxy),
            local_root,
            remote_root,
        })
    }

    pub fn reach(&self) -> Reach {
        self.reach
    }

    pub fn user(&self) -> &str {
        &self.user
    }

    pub fn host(&self) -> &str {
        &self.host
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    pub fn identity(&self) -> Option<&Path> {
        self.identity.as_deref()
    }

    pub fn proxy_command(&self) -> Option<&str> {
        self.proxy_command.as_deref()
    }

    pub fn local_root(&self) -> &Path {
        &self.local_root
    }

    pub fn remote_root(&self) -> &Path {
        &self.remote_root
    }

    fn open(spec: Spec<'_>) -> Result<Self, RemoteError> {
        check::user(spec.user)?;
        check::host(spec.host)?;
        check::port(spec.port)?;
        if let Some(command) = &spec.proxy_command {
            check::proxy(command)?;
        }
        Ok(Self {
            reach: spec.reach,
            user: spec.user.to_string(),
            host: spec.host.to_string(),
            port: spec.port,
            identity: spec.identity.map(check::identity).transpose()?,
            proxy_command: spec.proxy_command,
            local_root: check::root(spec.local_root)?,
            remote_root: check::root(spec.remote_root)?,
        })
    }
}

struct Spec<'a> {
    reach: Reach,
    user: &'a str,
    host: &'a str,
    port: u16,
    identity: Option<&'a Path>,
    proxy_command: Option<String>,
    local_root: &'a Path,
    remote_root: &'a Path,
}

fn pod_proxy(namespace: &str, pod: &str, container: Option<&str>) -> Result<String, RemoteError> {
    let base = format!("kubectl exec -i -n {namespace} {pod}");
    match container {
        Some(name) => {
            let name = check::token(name)?;
            Ok(format!("{base} -c {name} -- nc %h %p"))
        }
        None => Ok(format!("{base} -- nc %h %p")),
    }
}
