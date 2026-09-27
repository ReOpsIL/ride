use std::path::Path;

pub fn relative(root: Option<&Path>, path: &Path) -> String {
    match root {
        Some(root) => path
            .strip_prefix(root)
            .unwrap_or(path)
            .to_string_lossy()
            .replace('\\', "/"),
        None => path.to_string_lossy().into_owned(),
    }
}
