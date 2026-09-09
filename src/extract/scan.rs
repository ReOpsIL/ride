use std::fs;
use std::path::{Path, PathBuf};

use crate::skip::{skip_dir_name, under_root};

use super::item::CrateContext;

pub fn leftover_src_files(
    crate_root: &Path,
    visited: &std::collections::HashSet<PathBuf>,
    ctx: &CrateContext,
) -> Vec<(PathBuf, Vec<String>)> {
    let src = crate_root.join("src");
    if !src.is_dir() {
        return Vec::new();
    }
    let mut out = Vec::new();
    walk_dir(&src, crate_root, visited, ctx, &mut out);
    out
}

fn walk_dir(
    dir: &Path,
    crate_root: &Path,
    visited: &std::collections::HashSet<PathBuf>,
    ctx: &CrateContext,
    out: &mut Vec<(PathBuf, Vec<String>)>,
) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if path.is_dir() {
            if skip_dir_name(&name) || matches!(name.as_ref(), "tests" | "benches" | "examples") {
                continue;
            }
            walk_dir(&path, crate_root, visited, ctx, out);
            continue;
        }
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }
        let Ok(canon) = path.canonicalize() else {
            continue;
        };
        if visited.contains(&canon) || !under_root(&canon, crate_root) {
            continue;
        }
        out.push((canon, infer_module_path(&path, crate_root, &ctx.crate_name)));
    }
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
