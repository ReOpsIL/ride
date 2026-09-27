use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

use crate::files::files_under;
use crate::skip::{MAX_RS_BYTES, skip_dir_name, skip_index_file, under_root};

use super::ExtractError;
use super::item::CrateContext;

pub fn read_rs(path: &Path, crate_name: &str) -> Result<Option<String>, ExtractError> {
    let meta = fs::metadata(path).map_err(|source| ExtractError::Io {
        path: path.to_path_buf(),
        source,
    })?;
    if meta.len() > MAX_RS_BYTES || skip_index_file(path, crate_name, meta.len()) {
        return Ok(None);
    }
    let bytes = fs::read(path).map_err(|source| ExtractError::Io {
        path: path.to_path_buf(),
        source,
    })?;
    Ok(String::from_utf8(bytes).ok())
}

pub fn leftover_src_files(
    crate_root: &Path,
    visited: &HashSet<PathBuf>,
    ctx: &CrateContext,
) -> Vec<(PathBuf, Vec<String>)> {
    let src = crate_root.join("src");
    if !src.is_dir() {
        return Vec::new();
    }
    files_under(&src, skipped_dir)
        .into_iter()
        .filter(|path| path.extension().and_then(|e| e.to_str()) == Some("rs"))
        .filter_map(|path| {
            let canon = path.canonicalize().ok()?;
            (!visited.contains(&canon) && under_root(&canon, crate_root))
                .then(|| (canon, infer_module_path(&path, crate_root, &ctx.crate_name)))
        })
        .collect()
}

fn skipped_dir(name: &str) -> bool {
    skip_dir_name(name) || matches!(name, "tests" | "benches" | "examples")
}

fn infer_module_path(file: &Path, crate_root: &Path, crate_name: &str) -> Vec<String> {
    let mut parts = vec![crate_name.to_string()];
    let rel = file.strip_prefix(crate_root.join("src")).unwrap_or(file);
    let mut comps: Vec<String> = rel
        .iter()
        .filter_map(|s| s.to_str().map(str::to_string))
        .collect();
    if let Some(last) = comps.last().cloned() {
        if matches!(last.as_str(), "mod.rs" | "lib.rs" | "main.rs") {
            comps.pop();
        } else if let Some(stem) = Path::new(&last).file_stem().and_then(|s| s.to_str()) {
            comps.pop();
            comps.push(stem.to_string());
        }
    }
    parts.extend(comps);
    parts
}
