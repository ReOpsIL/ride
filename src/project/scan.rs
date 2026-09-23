use std::collections::VecDeque;
use std::fs;
use std::path::{Path, PathBuf};

const MARKERS: [&str; 6] = [
    "Cargo.toml",
    "CMakeLists.txt",
    "Makefile",
    "GNUmakefile",
    "compile_commands.json",
    "build/compile_commands.json",
];
const MAX_DEPTH: usize = 5;
const MAX_DIRS: usize = 4000;

pub fn is_project_root(dir: &Path) -> bool {
    MARKERS.iter().any(|name| dir.join(name).is_file())
}

pub fn project_roots(root: &Path) -> Vec<PathBuf> {
    let mut found = Vec::new();
    let mut queue = VecDeque::from([(root.to_path_buf(), 0)]);
    let mut visited = 0;
    while let Some((dir, depth)) = queue.pop_front() {
        visited += 1;
        if is_project_root(&dir) {
            found.push(dir);
            continue;
        }
        if depth == MAX_DEPTH || visited > MAX_DIRS {
            continue;
        }
        queue.extend(subdirs(&dir).into_iter().map(|sub| (sub, depth + 1)));
    }
    found.sort();
    found
}

fn subdirs(dir: &Path) -> Vec<PathBuf> {
    let Ok(entries) = fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut dirs: Vec<PathBuf> = entries
        .flatten()
        .filter(|entry| entry.file_type().is_ok_and(|kind| kind.is_dir()))
        .filter(|entry| !skipped(&entry.file_name().to_string_lossy()))
        .map(|entry| entry.path())
        .collect();
    dirs.sort();
    dirs
}

fn skipped(name: &str) -> bool {
    name.starts_with('.')
        || name.starts_with("cmake-build-")
        || matches!(name, "target" | "node_modules" | "build")
}
