use std::path::{Component, Path, PathBuf};

pub fn absolute(base: &Path, path: &Path) -> PathBuf {
    if path.is_absolute() || base.as_os_str().is_empty() {
        return normalize(path);
    }
    normalize(&base.join(path))
}

pub fn absolute_string(base: &Path, path: &str) -> String {
    absolute(base, Path::new(path)).display().to_string()
}

fn normalize(path: &Path) -> PathBuf {
    let mut out = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => parent(&mut out),
            other => out.push(other),
        }
    }
    out
}

fn parent(out: &mut PathBuf) {
    match out.components().next_back() {
        Some(Component::Normal(_)) => {
            out.pop();
        }
        Some(Component::RootDir | Component::Prefix(_)) => {}
        _ => out.push(Component::ParentDir),
    }
}
