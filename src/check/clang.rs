use crate::error::EngineError;
use crate::ffi::CheckResult;
use crate::highlight::Lang;
use crate::process::run_piped;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use super::clang_parse::{parse_clang, parse_clang_live};
use super::invocation::invocation;
use super::output::stderr_tail;

const DIAG_FLAGS: &[&str] = &[
    "-fsyntax-only",
    "-fno-color-diagnostics",
    "-fdiagnostics-print-source-range-info",
    "-fdiagnostics-parseable-fixits",
];

pub fn run_clang_check(file: &Path) -> Result<CheckResult, EngineError> {
    let text = std::fs::read_to_string(file).map_err(|e| EngineError::io(file, e))?;
    let lang = Lang::for_buffer(file.to_str(), &text);
    let (mut cmd, cwd) = build_command(file, lang)?;
    cmd.arg(file);
    let (success, stderr) = run(&mut cmd, &cwd)?;
    Ok(CheckResult {
        success,
        diagnostics: parse_clang(&stderr, &cwd),
        stderr_tail: stderr_tail(&stderr),
    })
}

pub fn check_c_live(file: &Path, text: &str) -> Result<CheckResult, EngineError> {
    let lang = Lang::for_buffer(file.to_str(), text);
    let (mut cmd, cwd) = build_command(file, lang)?;
    if let Some(dir) = file.parent() {
        cmd.arg("-iquote").arg(dir);
    }
    cmd.arg("-");
    let (success, stderr) = run_stdin(&mut cmd, &cwd, text)?;
    Ok(CheckResult {
        success,
        diagnostics: parse_clang_live(&stderr, &cwd, file, text),
        stderr_tail: stderr_tail(&stderr),
    })
}

fn build_command(file: &Path, lang: Lang) -> Result<(Command, PathBuf), EngineError> {
    let Some(invocation) = invocation(file, lang) else {
        return Err(EngineError::Tool {
            message: format!("clang: not a C or C++ file: {}", file.display()),
        });
    };
    let mut cmd = crate::toolchain::tool("clang");
    cmd.args(invocation.args);
    cmd.args(DIAG_FLAGS);
    Ok((cmd, invocation.directory))
}

fn run(cmd: &mut Command, cwd: &Path) -> Result<(bool, String), EngineError> {
    if cwd.is_dir() {
        cmd.current_dir(cwd);
    }
    let output = cmd.output().map_err(|e| EngineError::Tool {
        message: format!("clang: {e}"),
    })?;
    Ok((
        output.status.success(),
        String::from_utf8_lossy(&output.stderr).into_owned(),
    ))
}

fn run_stdin(cmd: &mut Command, cwd: &Path, text: &str) -> Result<(bool, String), EngineError> {
    if cwd.is_dir() {
        cmd.current_dir(cwd);
    }
    cmd.stdout(Stdio::null()).stderr(Stdio::piped());
    let output = run_piped(cmd, "clang", text)?;
    Ok((
        output.status.success(),
        String::from_utf8_lossy(&output.stderr).into_owned(),
    ))
}
