use std::path::{Path, PathBuf};

use crate::skip::under_root;

#[derive(Debug, Clone, Copy)]
pub struct ModScope<'a> {
    pub file: &'a Path,
    pub dir: &'a Path,
    pub inline: bool,
}

pub struct ModFile {
    pub file: PathBuf,
    pub dir: PathBuf,
}

pub fn root_dir(file: &Path) -> PathBuf {
    file.parent().map(Path::to_path_buf).unwrap_or_default()
}

pub fn inferred_dir(file: &Path) -> PathBuf {
    let parent = root_dir(file);
    match file.file_name().and_then(|n| n.to_str()) {
        Some("mod.rs" | "lib.rs" | "main.rs") => parent,
        _ => parent.join(file.file_stem().unwrap_or_default()),
    }
}

pub fn resolve_mod_file(
    scope: ModScope<'_>,
    name: &str,
    path_attr: Option<&str>,
    crate_root: &Path,
) -> Option<ModFile> {
    let found = match path_attr {
        Some(p) => by_path_attr(scope, p),
        None => by_name(scope.dir, name),
    }?;
    under_root(&found.file, crate_root).then_some(found)
}

fn by_path_attr(scope: ModScope<'_>, attr: &str) -> Option<ModFile> {
    let base = if scope.inline {
        scope.dir.to_path_buf()
    } else {
        root_dir(scope.file)
    };
    let file = base.join(attr);
    file.is_file().then(|| ModFile {
        dir: root_dir(&file),
        file,
    })
}

fn by_name(dir: &Path, name: &str) -> Option<ModFile> {
    let child_dir = dir.join(name);
    [dir.join(format!("{name}.rs")), child_dir.join("mod.rs")]
        .into_iter()
        .find(|file| file.is_file())
        .map(|file| ModFile {
            file,
            dir: child_dir,
        })
}
