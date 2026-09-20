use std::path::{Path, PathBuf};

pub fn absolute(base: &Path, path: &Path) -> PathBuf {
    if path.is_absolute() || base.as_os_str().is_empty() {
        return path.to_path_buf();
    }
    base.join(path)
}

pub fn absolute_string(base: &Path, path: &str) -> String {
    absolute(base, Path::new(path)).display().to_string()
}
