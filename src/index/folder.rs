use std::fs;
use std::path::Path;

use crate::extract::{CrateContext, ExtractError, ItemDoc, Scope, extract_source};
use crate::skip::{MAX_RS_BYTES, skip_dir_name, skip_index_file};

pub fn extract_plain_folder(root: &Path, scope: Scope) -> Result<Vec<ItemDoc>, ExtractError> {
    let crate_name = root
        .file_name()
        .map(|n| n.to_string_lossy().replace('-', "_"))
        .unwrap_or_else(|| "workspace".into());
    let ctx = CrateContext {
        crate_name: crate_name.clone(),
        crate_version: "0.0.0".into(),
        crate_root: root.to_path_buf(),
        edition: None,
        features: Vec::new(),
        scope,
    };
    let mut items = Vec::new();
    walk_rs(root, &crate_name, &ctx, &mut items)?;
    Ok(items)
}

fn walk_rs(
    dir: &Path,
    crate_name: &str,
    ctx: &CrateContext,
    items: &mut Vec<ItemDoc>,
) -> Result<(), ExtractError> {
    let entries = fs::read_dir(dir).map_err(|source| ExtractError::Io {
        path: dir.to_path_buf(),
        source,
    })?;
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if path.is_dir() {
            if skip_dir_name(&name) {
                continue;
            }
            walk_rs(&path, crate_name, ctx, items)?;
            continue;
        }
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }
        let meta = fs::metadata(&path).map_err(|source| ExtractError::Io {
            path: path.clone(),
            source,
        })?;
        if meta.len() > MAX_RS_BYTES || skip_index_file(&path, crate_name, meta.len()) {
            continue;
        }
        let Ok(source) = fs::read_to_string(&path) else {
            continue;
        };
        items.extend(extract_source(&source, ctx, &[crate_name.to_string()])?);
    }
    Ok(())
}
