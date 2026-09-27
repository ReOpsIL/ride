use std::path::Path;

use crate::extract::{CrateContext, ExtractError, ItemDoc, Scope, extract_source, read_rs};
use crate::files::files_under;
use crate::skip::skip_dir_name;

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
    let module_path = [crate_name];
    let mut items = Vec::new();
    for path in files_under(root, skip_dir_name) {
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }
        if let Some(source) = read_rs(&path, &ctx.crate_name)? {
            items.extend(extract_source(&source, &ctx, &module_path)?);
        }
    }
    Ok(items)
}
