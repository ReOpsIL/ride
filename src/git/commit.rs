use crate::error::EngineError;

use super::cli::Git;

pub fn commit(git: &Git, message: &str, amend: bool) -> Result<String, EngineError> {
    let message = message.trim();
    let out = match (message.is_empty(), amend) {
        (true, true) => git.run(&["commit", "--amend", "--no-edit"])?,
        (true, false) => return Err(EngineError::git("the commit message is empty")),
        (false, true) => git.run_with_input(&["commit", "--amend", "--file=-"], message)?,
        (false, false) => git.run_with_input(&["commit", "--file=-"], message)?,
    };
    Ok(out.stdout.lines().next().unwrap_or_default().to_string())
}

pub fn last_message(git: &Git) -> Result<String, EngineError> {
    let out = git.run(&["log", "-1", "--format=%B"])?;
    Ok(out.stdout.trim_end().to_string())
}
