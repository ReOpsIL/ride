use std::path::{Path, PathBuf};

pub fn document_uri(path: &Path) -> String {
    match std::fs::canonicalize(path) {
        Ok(real) => file_uri(&real),
        Err(_) => file_uri(path),
    }
}

pub fn uri_path(uri: &str) -> Option<PathBuf> {
    let encoded = uri.strip_prefix("file://")?.as_bytes();
    let mut bytes = Vec::with_capacity(encoded.len());
    let mut i = 0;
    while i < encoded.len() {
        let hex = encoded
            .get(i + 1..i + 3)
            .and_then(|h| std::str::from_utf8(h).ok());
        match (encoded[i], hex.and_then(|h| u8::from_str_radix(h, 16).ok())) {
            (b'%', Some(byte)) => {
                bytes.push(byte);
                i += 3;
            }
            (byte, _) => {
                bytes.push(byte);
                i += 1;
            }
        }
    }
    String::from_utf8(bytes).ok().map(PathBuf::from)
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
    fn a_uri_decodes_back_to_its_path() {
        let path = Path::new("/tmp/my crate/é.rs");
        assert_eq!(uri_path(&file_uri(path)), Some(path.to_path_buf()));
    }

    #[test]
    fn spaces_and_non_ascii_are_percent_encoded() {
        assert_eq!(
            file_uri(Path::new("/tmp/my crate/é.rs")),
            "file:///tmp/my%20crate/%C3%A9.rs"
        );
    }
}
