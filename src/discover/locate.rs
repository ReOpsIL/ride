use std::path::{Path, PathBuf};

pub fn cargo_workspace_root(dir: &Path) -> Option<PathBuf> {
    let output = crate::toolchain::tool("cargo")
        .args(["locate-project", "--workspace", "--message-format", "plain"])
        .current_dir(dir)
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let manifest = String::from_utf8_lossy(&output.stdout);
    Path::new(manifest.trim()).parent().map(Path::to_path_buf)
}
