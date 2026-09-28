use std::path::Path;

pub fn document_uri(path: &Path) -> String {
    match std::fs::canonicalize(path) {
        Ok(real) => file_uri(&real),
        Err(_) => file_uri(path),
    }
}

pub fn file_uri(path: &Path) -> String {
    let mut out = String::from("file://");
    for byte in path.to_string_lossy().bytes() {
        if byte.is_ascii_alphanumeric() || b"/-._~".contains(&byte) {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_symlinked_document_uses_the_resolved_path() {
        let dir = tempfile::tempdir().expect("tempdir");
        let real = dir.path().join("real.rs");
        std::fs::write(&real, "").expect("write");
        let link = dir.path().join("link.rs");
        std::os::unix::fs::symlink(&real, &link).expect("symlink");
        let resolved = std::fs::canonicalize(&real).expect("canonical");
        assert_eq!(document_uri(&link), file_uri(&resolved));
    }

    #[test]
    fn spaces_and_non_ascii_are_percent_encoded() {
        assert_eq!(
            file_uri(Path::new("/tmp/my crate/é.rs")),
            "file:///tmp/my%20crate/%C3%A9.rs"
        );
    }
}
