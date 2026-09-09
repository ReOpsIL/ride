use std::path::{Path, PathBuf};

use crate::skip::under_root;

pub fn resolve_mod_file(
    current_file: &Path,
    name: &str,
    path_attr: Option<&str>,
    crate_root: &Path,
) -> Option<PathBuf> {
    let parent = current_file.parent()?;
    let candidate = if let Some(p) = path_attr {
        parent.join(p)
    } else {
        let dir = module_dir(current_file, parent);
        let file = dir.join(format!("{name}.rs"));
        if file.is_file() {
            file
        } else {
            dir.join(name).join("mod.rs")
        }
    };
    if candidate.is_file() && under_root(&candidate, crate_root) {
        Some(candidate)
    } else {
        None
    }
}

fn module_dir(current_file: &Path, parent: &Path) -> PathBuf {
    match current_file.file_name().and_then(|n| n.to_str()) {
        Some("mod.rs" | "lib.rs" | "main.rs") => parent.to_path_buf(),
        _ => parent.join(current_file.file_stem().unwrap_or_default()),
    }
}
