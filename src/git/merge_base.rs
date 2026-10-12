use crate::error::EngineError;

use super::cli::Git;

pub fn base(git: &Git) -> Result<String, EngineError> {
    if let Ok(out) = git.run(&["merge-base", "HEAD", "@{upstream}"]) {
        let found = out.stdout.trim();
        if !found.is_empty() {
            return Ok(found.to_string());
        }
    }
    head(git)
}

pub fn head(git: &Git) -> Result<String, EngineError> {
    let out = git.run(&["rev-parse", "HEAD"])?;
    let found = out.stdout.trim();
    if found.is_empty() {
        return Err(EngineError::git("HEAD is empty"));
    }
    Ok(found.to_string())
}

pub fn upstream(git: &Git) -> String {
    git.run(&[
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
    ])
    .ok()
    .map(|out| out.stdout.trim().to_string())
    .filter(|name| !name.is_empty())
    .unwrap_or_else(|| "HEAD".to_string())
}

pub fn user_name(git: &Git) -> String {
    git.run(&["config", "user.name"])
        .map(|out| out.stdout.trim().to_string())
        .unwrap_or_default()
}
