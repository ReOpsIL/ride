use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{RecompileCommand, SingleRun};
use crate::toolchain::find_tool;

enum Kind {
    C,
    Cpp,
    Rust,
}

impl Kind {
    fn for_path(path: &Path) -> Option<Self> {
        match path.extension()?.to_str()? {
            "c" => Some(Self::C),
            "cpp" | "cc" | "cxx" | "c++" | "C" => Some(Self::Cpp),
            "rs" => Some(Self::Rust),
            _ => None,
        }
    }

    fn tool(&self) -> &'static str {
        match self {
            Self::C => "clang",
            Self::Cpp => "clang++",
            Self::Rust => "rustc",
        }
    }

    fn flags(&self) -> &'static [&'static str] {
        match self {
            Self::C => &[],
            Self::Cpp => &["-std=c++20"],
            Self::Rust => &["--edition", "2021"],
        }
    }
}

pub fn single_file_command(path: &Path, out_dir: &Path) -> Result<SingleRun, EngineError> {
    let kind = Kind::for_path(path).ok_or_else(|| EngineError::Tool {
        message: format!("no single-file runner for {}", path.display()),
    })?;
    let name = path
        .file_stem()
        .and_then(|s| s.to_str())
        .ok_or_else(|| EngineError::Tool {
            message: format!("no file name in {}", path.display()),
        })?;
    let tool = find_tool(kind.tool()).ok_or_else(|| EngineError::Tool {
        message: format!("{} not found on PATH", kind.tool()),
    })?;
    std::fs::create_dir_all(out_dir).map_err(|e| EngineError::io(out_dir, e))?;
    let output = out_dir.join(name);
    let mut compile = vec![tool.display().to_string()];
    compile.extend(kind.flags().iter().map(|f| (*f).to_string()));
    compile.push(path.display().to_string());
    compile.push("-o".to_string());
    compile.push(output.display().to_string());
    Ok(SingleRun {
        compile,
        run: vec![output.display().to_string()],
        output: output.display().to_string(),
    })
}

pub fn recompile_command(path: &Path) -> Option<RecompileCommand> {
    let command = crate::check::raw_command(path)?;
    Some(RecompileCommand {
        argv: command.args,
        directory: command.directory.display().to_string(),
    })
}
