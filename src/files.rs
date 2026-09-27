use std::fs::{self, DirEntry};
use std::path::{Path, PathBuf};

enum EntryKind {
    Dir,
    File,
    Other,
}

pub fn files_under(root: &Path, skip_dir: impl Fn(&str) -> bool) -> Vec<PathBuf> {
    let mut files = Vec::new();
    let mut dirs = vec![root.to_path_buf()];
    while let Some(dir) = dirs.pop() {
        let Ok(entries) = fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            match classify(&entry) {
                EntryKind::Dir if !skip_dir(&entry.file_name().to_string_lossy()) => {
                    dirs.push(entry.path())
                }
                EntryKind::File => files.push(entry.path()),
                _ => {}
            }
        }
    }
    files
}

fn classify(entry: &DirEntry) -> EntryKind {
    let Ok(kind) = entry.file_type() else {
        return EntryKind::Other;
    };
    if kind.is_dir() {
        EntryKind::Dir
    } else if kind.is_file() || (kind.is_symlink() && entry.path().is_file()) {
        EntryKind::File
    } else {
        EntryKind::Other
    }
}
