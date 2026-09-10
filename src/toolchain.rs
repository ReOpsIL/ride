use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::OnceLock;

const EXTRA_DIRS: [&str; 7] = [
    "/usr/local/bin",
    "/opt/homebrew/bin",
    "/opt/homebrew/opt/llvm/bin",
    "/usr/local/opt/llvm/bin",
    "/usr/local/cargo/bin",
    "/Library/Developer/CommandLineTools/usr/bin",
    "/usr/bin",
];

pub fn tool(name: &str) -> Command {
    Command::new(tool_path(name))
}

pub fn tool_path(name: &str) -> PathBuf {
    find_tool(name).unwrap_or_else(|| PathBuf::from(name))
}

pub fn find_tool(name: &str) -> Option<PathBuf> {
    on_path(name).or_else(|| {
        candidate_dirs()
            .into_iter()
            .map(|d| d.join(name))
            .find(|p| p.is_file())
    })
}

pub fn install_hint(name: &str) -> &'static str {
    match name {
        "clang-format" => {
            "install Xcode or the Command Line Tools (xcode-select --install), or brew install clang-format"
        }
        "rustfmt" => "rustup component add rustfmt",
        "cmake-format" => "pip install cmake-format, or brew install gersemi",
        "taplo" => "brew install taplo",
        _ => "install it and make sure it is on PATH",
    }
}

fn on_path(name: &str) -> Option<PathBuf> {
    let path = env::var_os("PATH")?;
    env::split_paths(&path)
        .map(|d| d.join(name))
        .find(|p| p.is_file())
}

fn candidate_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Some(home) = env::var_os("CARGO_HOME") {
        dirs.push(Path::new(&home).join("bin"));
    }
    if let Some(home) = env::var_os("HOME") {
        dirs.push(Path::new(&home).join(".cargo/bin"));
        dirs.push(Path::new(&home).join(".local/bin"));
    }
    dirs.extend(developer_dirs().iter().cloned());
    dirs.extend(EXTRA_DIRS.iter().map(PathBuf::from));
    dirs
}

fn developer_dirs() -> &'static [PathBuf] {
    static DIRS: OnceLock<Vec<PathBuf>> = OnceLock::new();
    DIRS.get_or_init(|| {
        let mut roots = vec![PathBuf::from("/Applications/Xcode.app/Contents/Developer")];
        if let Ok(output) = Command::new("/usr/bin/xcode-select").arg("-p").output()
            && output.status.success()
        {
            let dir = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !dir.is_empty() {
                roots.insert(0, PathBuf::from(dir));
            }
        }
        roots
            .into_iter()
            .flat_map(|root| {
                [
                    root.join("Toolchains/XcodeDefault.xctoolchain/usr/bin"),
                    root.join("usr/bin"),
                ]
            })
            .filter(|d| d.is_dir())
            .collect()
    })
}
