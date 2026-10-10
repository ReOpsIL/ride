use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::time::Duration;

use crate::error::EngineError;
use crate::process::{IdleError, output_idle, run_piped};
use crate::toolchain::{search_path, tool};

const SUCCESS: &[i32] = &[0];

#[derive(Debug, Clone)]
pub struct Git {
    dir: PathBuf,
}

#[derive(Debug, Clone, Default)]
pub struct Captured {
    pub stdout: String,
    pub stderr: String,
}

impl Captured {
    pub fn transcript(&self) -> String {
        [self.stdout.trim(), self.stderr.trim()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<Vec<_>>()
            .join("\n")
    }
}

impl Git {
    pub fn at(dir: impl AsRef<Path>) -> Self {
        Self {
            dir: dir.as_ref().to_path_buf(),
        }
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }

    pub fn run(&self, args: &[&str]) -> Result<Captured, EngineError> {
        self.run_accepting(args, SUCCESS)
    }

    pub fn run_accepting(&self, args: &[&str], codes: &[i32]) -> Result<Captured, EngineError> {
        let output = self
            .command(args)
            .stdin(Stdio::null())
            .output()
            .map_err(|e| EngineError::git(format!("cannot run git: {e}")))?;
        finish(args, output, codes)
    }

    pub fn run_idle(&self, args: &[&str], idle: Duration) -> Result<Captured, EngineError> {
        let mut cmd = self.command(args);
        match output_idle(&mut cmd, idle) {
            Ok(output) => finish(args, output, SUCCESS),
            Err(IdleError::TimedOut) => Err(EngineError::git(format!(
                "git {} timed out; a credential helper may be waiting for input",
                args.first().copied().unwrap_or("git")
            ))),
            Err(IdleError::Io(err)) => Err(EngineError::git(format!("cannot run git: {err}"))),
        }
    }

    pub fn run_with_input(&self, args: &[&str], input: &str) -> Result<Captured, EngineError> {
        let mut cmd = self.command(args);
        cmd.stdout(Stdio::piped()).stderr(Stdio::piped());
        let output = run_piped(&mut cmd, "git", input)?;
        finish(args, output, SUCCESS)
    }

    pub fn succeeds(&self, args: &[&str]) -> bool {
        self.run(args).is_ok()
    }

    fn command(&self, args: &[&str]) -> Command {
        let mut cmd = tool("git");
        cmd.arg("-C")
            .arg(&self.dir)
            .args(["-c", "core.quotepath=off", "-c", "color.ui=false"])
            .args(args)
            .env("PATH", search_path())
            .env("GIT_TERMINAL_PROMPT", "0")
            .env("GIT_OPTIONAL_LOCKS", "0")
            .env("LC_ALL", "C");
        cmd
    }
}

fn finish(args: &[&str], output: Output, codes: &[i32]) -> Result<Captured, EngineError> {
    let captured = Captured {
        stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
        stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
    };
    match output.status.code() {
        Some(code) if codes.contains(&code) => Ok(captured),
        _ => Err(failure(args, &captured)),
    }
}

fn failure(args: &[&str], captured: &Captured) -> EngineError {
    let detail = captured.transcript();
    let verb = args.first().copied().unwrap_or("git");
    if detail.is_empty() {
        EngineError::git(format!("git {verb} failed"))
    } else {
        EngineError::git(detail)
    }
}
