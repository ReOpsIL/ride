use std::fs;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};

pub fn ref_index_dir(index_dir: &Path, refs_dir: Option<&str>, root: &Path) -> PathBuf {
    let base = match refs_dir {
        Some(dir) => PathBuf::from(dir),
        None => index_dir.parent().unwrap_or(index_dir).join("refs"),
    };
    base.join(root_digest(root))
}

fn root_digest(root: &Path) -> String {
    let canonical = fs::canonicalize(root).unwrap_or_else(|_| root.to_path_buf());
    let mut hasher = Sha256::new();
    hasher.update(canonical.to_string_lossy().as_bytes());
    hasher.finalize().iter().fold(String::new(), |mut out, b| {
        use std::fmt::Write;
        let _ = write!(out, "{b:02x}");
        out
    })
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
        let a = ref_index_dir(&index_dir, None, &real);
        let b = ref_index_dir(&index_dir, None, &link);
        assert_eq!(a, b);
        let c = ref_index_dir(&index_dir, None, Path::new(&format!("{}/", real.display())));
        assert_eq!(a, c);
    }

    #[test]
    fn an_override_replaces_the_support_root() {
        let index_dir = Path::new("/support/index");
        let d = ref_index_dir(index_dir, Some("/tmp/iso"), Path::new("/nowhere"));
        assert!(d.starts_with("/tmp/iso"));
        assert_ne!(d.parent(), Some(Path::new("/support/refs")));
    }
}
