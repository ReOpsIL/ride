use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

const EXTRA_DIRS: [&str; 4] = [
    "/usr/local/bin",
    "/opt/homebrew/bin",
    "/usr/local/cargo/bin",
    "/usr/bin",
];

pub fn tool(name: &str) -> Command {
    Command::new(tool_path(name))
}

pub fn tool_path(name: &str) -> PathBuf {
    if let Some(found) = on_path(name) {
        return found;
    }
    candidate_dirs()
        .into_iter()
        .map(|d| d.join(name))
        .find(|p| p.is_file())
        .unwrap_or_else(|| PathBuf::from(name))
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
    }
    dirs.extend(EXTRA_DIRS.iter().map(PathBuf::from));
    dirs
}
