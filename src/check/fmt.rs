use std::io::Write;
use std::process::{Command, Stdio};

use crate::error::EngineError;
use crate::highlight::Lang;
use crate::toolchain::{find_tool, install_hint};

use super::make_fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Formatter {
    Rustfmt,
    ClangFormat,
    CmakeFormat,
    Taplo,
    Builtin,
}

impl Formatter {
    pub fn for_lang(lang: Lang) -> Option<Formatter> {
        match lang {
            Lang::Rust => Some(Formatter::Rustfmt),
            Lang::C | Lang::Cpp => Some(Formatter::ClangFormat),
            Lang::Cmake => Some(Formatter::CmakeFormat),
            Lang::Toml => Some(Formatter::Taplo),
            Lang::Make => Some(Formatter::Builtin),
            Lang::Markdown => None,
        }
    }

    pub fn tool(self) -> Option<&'static str> {
        match self {
            Formatter::Rustfmt => Some("rustfmt"),
            Formatter::ClangFormat => Some("clang-format"),
            Formatter::CmakeFormat => Some("cmake-format"),
            Formatter::Taplo => Some("taplo"),
            Formatter::Builtin => None,
        }
    }

    pub fn name(self) -> &'static str {
        self.tool().unwrap_or("builtin")
    }

    pub fn available(self) -> bool {
        match self.tool() {
            Some(name) => {
                find_tool(name).is_some()
                    || (self == Formatter::CmakeFormat && find_tool("gersemi").is_some())
            }
            None => true,
        }
    }
}

pub fn format_document(
    lang: Lang,
    text: &str,
    path: Option<&str>,
    edition: Option<&str>,
) -> Result<String, EngineError> {
    let Some(formatter) = Formatter::for_lang(lang) else {
        return Err(EngineError::Tool {
            message: "no formatter for this file type".into(),
        });
    };
    match formatter {
        Formatter::Rustfmt => format_source(text, edition),
        Formatter::ClangFormat => format_clang(text, path),
        Formatter::CmakeFormat => format_cmake(text),
        Formatter::Taplo => run("taplo", ["fmt", "-"], text),
        Formatter::Builtin => Ok(make_fmt::format(text)),
    }
}

pub fn format_source(text: &str, edition: Option<&str>) -> Result<String, EngineError> {
    run(
        "rustfmt",
        ["--emit", "stdout", "--edition", edition.unwrap_or("2024")],
        text,
    )
}

pub fn format_clang(text: &str, assume_filename: Option<&str>) -> Result<String, EngineError> {
    let assume = assume_filename.map(|name| format!("--assume-filename={name}"));
    run("clang-format", assume.iter().map(String::as_str), text)
}

fn format_cmake(text: &str) -> Result<String, EngineError> {
    if find_tool("cmake-format").is_some() {
        return run("cmake-format", ["-"], text);
    }
    run("gersemi", ["-"], text)
}

fn run<'a>(
    name: &str,
    args: impl IntoIterator<Item = &'a str>,
    text: &str,
) -> Result<String, EngineError> {
    let Some(path) = find_tool(name) else {
        return Err(EngineError::Tool {
            message: format!("{name} is not installed: {}", install_hint(name)),
        });
    };
    let mut cmd = Command::new(path);
    cmd.args(args);
    pipe(cmd, name, text)
}

fn pipe(mut cmd: Command, name: &str, text: &str) -> Result<String, EngineError> {
    let mut child = cmd
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| EngineError::Tool {
            message: format!("{name}: {e}"),
        })?;
    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(text.as_bytes())
            .map_err(|e| EngineError::Tool {
                message: format!("{name} stdin: {e}"),
            })?;
    }
    let output = child.wait_with_output().map_err(|e| EngineError::Tool {
        message: format!("{name}: {e}"),
    })?;
    if !output.status.success() {
        return Err(EngineError::Tool {
            message: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}
