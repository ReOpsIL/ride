use std::path::Path;

pub const MAX_RS_BYTES: u64 = 512 * 1024;
pub const MAX_SYS_C_BYTES: u64 = 64 * 1024;

pub fn skip_dir_name(name: &str) -> bool {
    matches!(name, "target" | ".git" | "node_modules")
}

pub fn skip_file(path: &Path) -> bool {
    let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
        return false;
    };
    if name.ends_with(".min.js") {
        return true;
    }
    matches!(
        path.extension().and_then(|e| e.to_str()),
        Some("o" | "a" | "so" | "dylib" | "rlib" | "bin" | "png" | "woff")
    )
}

pub fn is_sys_crate(name: &str) -> bool {
    name.ends_with("-sys")
}

pub fn skip_sys_c(path: &Path, len: u64) -> bool {
    matches!(
        path.extension().and_then(|e| e.to_str()),
        Some("c" | "cc" | "cpp" | "h" | "hpp")
    ) && len > MAX_SYS_C_BYTES
}

pub fn skip_index_file(path: &Path, crate_name: &str, len: u64) -> bool {
    skip_file(path) || (is_sys_crate(crate_name) && skip_sys_c(path, len))
}

pub fn under_root(path: &Path, root: &Path) -> bool {
    match (path.canonicalize(), root.canonicalize()) {
        (Ok(p), Ok(r)) => p.starts_with(r),
        _ => false,
    }
}
