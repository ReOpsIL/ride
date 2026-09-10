use crate::error::EngineError;
use crate::ffi::CheckResult;
use crate::highlight::Lang;
use std::path::{Path, PathBuf};

use super::clang_parse::parse_clang;
use super::compile_db;
use super::output::stderr_tail;

const DIAG_FLAGS: &[&str] = &[
    "-fsyntax-only",
    "-fno-color-diagnostics",
    "-fno-caret-diagnostics",
    "-fdiagnostics-print-source-range-info",
];

pub fn run_clang_check(file: &Path) -> Result<CheckResult, EngineError> {
    let text = std::fs::read_to_string(file).map_err(|e| EngineError::io(file, e))?;
    let lang = Lang::for_buffer(file.to_str(), &text);
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
    cmd.args(DIAG_FLAGS).arg(file);
    if cwd.is_dir() {
        cmd.current_dir(cwd);
    }
    let output = cmd.output().map_err(|e| EngineError::Tool {
        message: format!("clang: {e}"),
    })?;
    let stderr = String::from_utf8_lossy(&output.stderr);
    Ok(CheckResult {
        success: output.status.success(),
        diagnostics: parse_clang(&stderr),
        stderr_tail: stderr_tail(&stderr),
    })
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
