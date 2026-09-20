use std::path::{Path, PathBuf};

use crate::ffi::{UsageHit, UsagesResponse};

use super::schema::UsageRow;

pub struct DefContext {
    pub has_definition: bool,
    pub def_paths: Vec<PathBuf>,
}

pub fn build_response(
    name: String,
    rows: Vec<UsageRow>,
    root: Option<&Path>,
    ctx: &DefContext,
) -> UsagesResponse {
    let mut hits: Vec<UsageHit> = rows
        .into_iter()
        .map(|row| {
            let in_scope = ctx.has_definition && reaches(root, &row.path, &ctx.def_paths);
            UsageHit {
                path: row.path,
                line: row.line,
                byte_start: row.byte_start,
                byte_end: row.byte_end,
                enclosing_item: row.enclosing_item,
                enclosing_kind: row.enclosing_kind,
                ref_kind: row.kind.label().to_string(),
                in_definition_scope: in_scope,
            }
        })
        .collect();
    hits.sort_by(|a, b| {
        b.in_definition_scope
            .cmp(&a.in_definition_scope)
            .then_with(|| a.path.cmp(&b.path))
            .then_with(|| a.byte_start.cmp(&b.byte_start))
    });
    UsagesResponse {
        name,
        has_definition: ctx.has_definition,
        hits,
    }
}

fn reaches(root: Option<&Path>, rel: &str, def_paths: &[PathBuf]) -> bool {
    let abs = match root {
        Some(root) => root.join(rel),
        None => PathBuf::from(rel),
    };
    def_paths.iter().any(|d| same_file(d, &abs))
}

fn same_file(a: &Path, b: &Path) -> bool {
    let ca = a.canonicalize().unwrap_or_else(|_| a.to_path_buf());
    let cb = b.canonicalize().unwrap_or_else(|_| b.to_path_buf());
    ca == cb
}
