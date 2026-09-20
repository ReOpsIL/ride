use crate::error::EngineError;
use crate::ffi::CheckResult;
use crate::highlight::Lang;
use crate::process::run_piped;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use super::clang_parse::{parse_clang, parse_clang_live};
use super::compile_db;
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
    cmd.arg("-");
    let (success, stderr) = run_stdin(&mut cmd, &cwd, text)?;
    Ok(CheckResult {
        success,
        diagnostics: parse_clang_live(&stderr, &cwd, file, text),
        stderr_tail: stderr_tail(&stderr),
    })
}

fn build_command(file: &Path, lang: Lang) -> Result<(Command, PathBuf), EngineError> {
    let Some(lang_name) = lang.clang_name() else {
        return Err(EngineError::Tool {
            message: format!("clang: not a C or C++ file: {}", file.display()),
        });
    };
    let mut cmd = crate::toolchain::tool("clang");
    cmd.args(["-x", lang_name]);
    let cwd = match compile_db::lookup(file, lang) {
        Some(cc) => {
            cmd.args(cc.args);
            cc.directory
        }
        None => {
            cmd.args(default_args(lang, file));
            file.parent().map(Path::to_path_buf).unwrap_or_default()
        }
    };
    cmd.args(DIAG_FLAGS);
    Ok((cmd, cwd))
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

fn default_args(lang: Lang, file: &Path) -> Vec<String> {
    let std = match lang {
        Lang::Cpp => "-std=c++23",
        _ => "-std=c23",
    };
    let include = file
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."));
    vec![
        std.to_string(),
        "-Wall".to_string(),
        "-I".to_string(),
        include.display().to_string(),
    ]
}
