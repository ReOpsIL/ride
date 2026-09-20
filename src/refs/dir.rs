use std::fs;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};

pub fn ref_index_dir(index_dir: &Path, root: &Path) -> PathBuf {
    let support = index_dir.parent().unwrap_or(index_dir);
    let canonical = fs::canonicalize(root).unwrap_or_else(|_| root.to_path_buf());
    let mut hasher = Sha256::new();
    hasher.update(canonical.to_string_lossy().as_bytes());
    let digest = hasher.finalize().iter().fold(String::new(), |mut out, b| {
        use std::fmt::Write;
        let _ = write!(out, "{b:02x}");
        out
    });
    support.join("refs").join(digest)
}

#[cfg(test)]
mod tests {
    use super::ref_index_dir;
    use std::path::Path;

    #[test]
    fn a_symlinked_root_hashes_to_the_canonical_dir() {
        let tmp = std::env::temp_dir().join("ride-refs-canon");
        let real = tmp.join("real");
        let link = tmp.join("link");
        std::fs::create_dir_all(&real).unwrap();
        let _ = std::fs::remove_file(&link);
        std::os::unix::fs::symlink(&real, &link).unwrap();
        let index_dir = tmp.join("support").join("index");
        let a = ref_index_dir(&index_dir, &real);
        let b = ref_index_dir(&index_dir, &link);
        assert_eq!(a, b);
        let c = ref_index_dir(&index_dir, Path::new(&format!("{}/", real.display())));
        assert_eq!(a, c);
    }
}
