use std::path::{Path, PathBuf};

use super::check;
use super::endpoint::Endpoint;
use super::error::RemoteError;
use crate::abspath;

pub fn to_remote(
    local_root: &Path,
    remote_root: &Path,
    path: &Path,
) -> Result<PathBuf, RemoteError> {
    rewrite(local_root, remote_root, path)
}

pub fn to_local(
    local_root: &Path,
    remote_root: &Path,
    path: &Path,
) -> Result<PathBuf, RemoteError> {
    rewrite(remote_root, local_root, path)
}

pub fn spelled(path: &Path) -> Result<PathBuf, RemoteError> {
    let normal = abspath::absolute(Path::new(""), path);
    check::utf8(&normal)?;
    if normal.as_os_str().is_empty() {
        return Err(RemoteError::Path {
            path: path.display().to_string(),
        });
    }
    Ok(normal)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PathMap {
    local_root: PathBuf,
    remote_root: PathBuf,
}

impl Endpoint {
    pub fn path_map(&self) -> PathMap {
        PathMap {
            local_root: self.local_root().to_path_buf(),
            remote_root: self.remote_root().to_path_buf(),
        }
    }
}

impl PathMap {
    pub fn to_remote_str(&self, path: &str) -> String {
        mapped(path, |value| {
            to_remote(&self.local_root, &self.remote_root, value)
        })
    }

    pub fn to_local_str(&self, path: &str) -> String {
        mapped(path, |value| {
            to_local(&self.local_root, &self.remote_root, value)
        })
    }
}

fn mapped(path: &str, map: impl FnOnce(&Path) -> Result<PathBuf, RemoteError>) -> String {
    map(Path::new(path))
        .ok()
        .and_then(|mapped| mapped.to_str().map(str::to_string))
        .unwrap_or_else(|| path.to_string())
}

fn rewrite(from_root: &Path, to_root: &Path, path: &Path) -> Result<PathBuf, RemoteError> {
    let path = spelled(path)?;
    let shown = check::utf8(&path)?;
    let relative = path
        .strip_prefix(from_root)
        .map_err(|_| RemoteError::Outside { path: shown })?;
    if relative.as_os_str().is_empty() {
        return Ok(to_root.to_path_buf());
    }
    Ok(to_root.join(relative))
}
