use std::path::{Path, PathBuf};

use super::check;
use super::endpoint::Endpoint;
use super::error::RemoteError;
use super::map;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Invocation {
    pub program: String,
    pub args: Vec<String>,
}

impl Endpoint {
    pub fn invocation(
        &self,
        cwd: &Path,
        env: &[(&str, &str)],
        argv: &[&str],
    ) -> Result<Invocation, RemoteError> {
        let cwd = remote_cwd(self, cwd)?;
        let argv = prepare_argv(self, argv)?;
        let command = remote_command(&cwd, env, &argv)?;
        Ok(Invocation {
            program: "ssh".to_string(),
            args: ssh_args(self, &command)?,
        })
    }
}

fn remote_cwd(endpoint: &Endpoint, cwd: &Path) -> Result<PathBuf, RemoteError> {
    let path = if cwd.is_absolute() {
        map::spelled(cwd)?
    } else {
        map::spelled(&endpoint.local_root().join(cwd))?
    };
    if path.starts_with(endpoint.remote_root()) && !path.starts_with(endpoint.local_root()) {
        return Ok(path);
    }
    map::to_remote(endpoint.local_root(), endpoint.remote_root(), &path)
}

fn prepare_argv(endpoint: &Endpoint, argv: &[&str]) -> Result<Vec<String>, RemoteError> {
    if argv.is_empty() {
        return Err(RemoteError::EmptyCommand);
    }
    argv.iter().map(|arg| prepare_arg(endpoint, arg)).collect()
}

pub(crate) fn prepare_arg(endpoint: &Endpoint, arg: &str) -> Result<String, RemoteError> {
    if arg.is_empty() {
        return Err(RemoteError::EmptyCommand);
    }
    let path = Path::new(arg);
    if !path.is_absolute() {
        return Ok(arg.to_string());
    }
    let path = map::spelled(path)?;
    if path.starts_with(endpoint.local_root()) {
        return check::utf8(&map::to_remote(
            endpoint.local_root(),
            endpoint.remote_root(),
            &path,
        )?);
    }
    if path.starts_with(endpoint.remote_root()) {
        return check::utf8(&path);
    }
    Err(RemoteError::Outside {
        path: arg.to_string(),
    })
}

fn remote_command(
    cwd: &Path,
    env: &[(&str, &str)],
    argv: &[String],
) -> Result<String, RemoteError> {
    let dir = shell(&check::utf8(cwd)?)?;
    let exec = exec_line(env, argv)?;
    Ok(format!("cd {dir} && exec {exec}"))
}

fn exec_line(env: &[(&str, &str)], argv: &[String]) -> Result<String, RemoteError> {
    let mut words = Vec::new();
    if !env.is_empty() {
        words.push("env".to_string());
        for (name, value) in env {
            check::env_name(name)?;
            words.push(shell(&format!("{name}={value}"))?);
        }
    }
    for arg in argv {
        words.push(shell(arg)?);
    }
    Ok(words.join(" "))
}

pub(crate) fn ssh_args(endpoint: &Endpoint, command: &str) -> Result<Vec<String>, RemoteError> {
    let mut args = vec![
        "-o".to_string(),
        "BatchMode=yes".to_string(),
        "-o".to_string(),
        "RequestTTY=no".to_string(),
        "-o".to_string(),
        "ConnectTimeout=15".to_string(),
        "-o".to_string(),
        "ServerAliveInterval=30".to_string(),
        "-o".to_string(),
        "ServerAliveCountMax=4".to_string(),
        "-p".to_string(),
        endpoint.port().to_string(),
    ];
    if let Some(identity) = endpoint.identity() {
        args.push("-o".to_string());
        args.push("IdentitiesOnly=yes".to_string());
        args.push("-i".to_string());
        args.push(check::utf8(identity)?);
    }
    if let Some(proxy) = endpoint.proxy_command() {
        args.push("-o".to_string());
        args.push(format!("ProxyCommand={proxy}"));
    }
    args.push(format!("{}@{}", endpoint.user(), endpoint.host()));
    args.push("--".to_string());
    args.push(command.to_string());
    Ok(args)
}

pub(crate) fn shell(word: &str) -> Result<String, RemoteError> {
    shlex::try_quote(word)
        .map(|quoted| quoted.into_owned())
        .map_err(|_| RemoteError::Quote)
}
