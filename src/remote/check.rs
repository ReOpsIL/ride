use std::path::{Path, PathBuf};

use super::error::RemoteError;
use crate::abspath;

pub fn user(value: &str) -> Result<(), RemoteError> {
    token(value).map(|_| ()).map_err(|_| RemoteError::User {
        user: value.to_string(),
    })
}

pub fn host(value: &str) -> Result<(), RemoteError> {
    if value.len() > 253 || value.split('.').any(|label| !host_label(label)) {
        return Err(RemoteError::Host {
            host: value.to_string(),
        });
    }
    Ok(())
}

pub fn port(value: u16) -> Result<(), RemoteError> {
    if value == 0 {
        return Err(RemoteError::Port);
    }
    Ok(())
}

pub fn token(value: &str) -> Result<String, RemoteError> {
    if value.is_empty() || value.len() > 253 || value.contains("..") || !token_chars(value) {
        return Err(RemoteError::Name {
            name: value.to_string(),
        });
    }
    Ok(value.to_string())
}

pub fn proxy(value: &str) -> Result<(), RemoteError> {
    if value.is_empty() || value.chars().any(char::is_control) {
        return Err(RemoteError::Proxy);
    }
    Ok(())
}

pub fn identity(path: &Path) -> Result<PathBuf, RemoteError> {
    let text = utf8(path)?;
    if !path.is_absolute() || text.chars().any(char::is_control) {
        return Err(RemoteError::Identity { path: text });
    }
    Ok(abspath::absolute(Path::new(""), path))
}

pub fn root(path: &Path) -> Result<PathBuf, RemoteError> {
    let shown = utf8(path)?;
    let normal = abspath::absolute(Path::new(""), path);
    if !normal.is_absolute() || normal == Path::new("/") {
        return Err(RemoteError::Root { path: shown });
    }
    utf8(&normal)?;
    Ok(normal)
}

pub fn env_name(value: &str) -> Result<(), RemoteError> {
    let mut chars = value.chars();
    let Some(first) = chars.next() else {
        return Err(RemoteError::EnvName {
            name: value.to_string(),
        });
    };
    if !(first.is_ascii_alphabetic() || first == '_')
        || !chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
    {
        return Err(RemoteError::EnvName {
            name: value.to_string(),
        });
    }
    Ok(())
}

pub fn utf8(path: &Path) -> Result<String, RemoteError> {
    path.to_str()
        .map(str::to_string)
        .ok_or_else(|| RemoteError::Path {
            path: path.display().to_string(),
        })
}

fn host_label(value: &str) -> bool {
    let mut chars = value.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    first.is_ascii_alphanumeric()
        && value.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
        && !value.ends_with('-')
}

fn token_chars(value: &str) -> bool {
    let mut chars = value.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    first.is_ascii_alphanumeric()
        && chars.all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '.' | '-'))
}
