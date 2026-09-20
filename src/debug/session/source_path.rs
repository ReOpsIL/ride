use std::path::Path;

use crate::debug::protocol::Source;

pub fn source_of(path: &str) -> Source {
    let name = Path::new(path)
        .file_name()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or_else(|| path.to_string());
    Source::file(path, &name)
}

pub fn twin(path: &str) -> Option<String> {
    let resolved = canonical(path);
    (resolved != path).then_some(resolved)
}

pub fn same_file(left: &str, right: &str) -> bool {
    left == right || canonical(left) == canonical(right)
}

fn canonical(path: &str) -> String {
    std::fs::canonicalize(path)
        .map(|resolved| resolved.to_string_lossy().to_string())
        .unwrap_or_else(|_| path.to_string())
}
