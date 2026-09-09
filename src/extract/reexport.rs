use std::path::PathBuf;

use crate::ffi::ItemKind;

use super::item::{ItemDoc, Scope, Visibility, join_path};

#[derive(Debug, Clone)]
pub struct Reexport {
    pub module_path: Vec<String>,
    pub vis: Visibility,
    pub source_path: PathBuf,
    pub byte_range: (u32, u32),
    pub kind: ReexportKind,
}

#[derive(Debug, Clone)]
pub enum ReexportKind {
    Named { target: Vec<String>, alias: String },
    Glob { module: Vec<String> },
}

pub fn apply(items: &[ItemDoc], reexports: &[Reexport]) -> Vec<ItemDoc> {
    let mut extra = Vec::new();
    for re in reexports {
        match &re.kind {
            ReexportKind::Named { target, alias } => {
                extra.push(remap(items, re, target, alias));
            }
            ReexportKind::Glob { module } => {
                extra.extend(glob(items, re, module));
            }
        }
    }
    extra
}

fn remap(items: &[ItemDoc], re: &Reexport, target: &[String], alias: &str) -> ItemDoc {
    let target_path = target.join("::");
    let path = join_path(&re.module_path, alias);
    if let Some(src) = items.iter().find(|i| i.path == target_path) {
        let mut doc = src.clone();
        doc.path = path;
        doc.name = alias.to_string();
        doc.visibility = re.vis;
        doc.source_path = re.source_path.clone();
        doc.byte_range = re.byte_range;
        return doc;
    }
    ItemDoc {
        crate_name: items
            .first()
            .map(|i| i.crate_name.clone())
            .unwrap_or_default(),
        crate_version: items
            .first()
            .map(|i| i.crate_version.clone())
            .unwrap_or_default(),
        item_kind: guess_kind(alias),
        path,
        name: alias.to_string(),
        signature: String::new(),
        doc_first_paragraph: String::new(),
        source_chunk: String::new(),
        source_path: re.source_path.clone(),
        byte_range: re.byte_range,
        edition: items.first().and_then(|i| i.edition.clone()),
        features: Vec::new(),
        visibility: re.vis,
        scope: items.first().map(|i| i.scope).unwrap_or(Scope::Cache),
    }
}

fn glob(items: &[ItemDoc], re: &Reexport, module: &[String]) -> Vec<ItemDoc> {
    let prefix = module.join("::");
    let depth = module.len() + 1;
    items
        .iter()
        .filter(|i| {
            if i.visibility != Visibility::Pub {
                return false;
            }
            let parts: Vec<&str> = i.path.split("::").collect();
            parts.len() == depth && i.path.starts_with(&format!("{prefix}::"))
        })
        .map(|src| {
            let mut doc = src.clone();
            doc.path = join_path(&re.module_path, &src.name);
            doc.visibility = re.vis;
            doc.source_path = re.source_path.clone();
            doc.byte_range = re.byte_range;
            doc
        })
        .collect()
}

fn guess_kind(name: &str) -> ItemKind {
    if name.chars().next().is_some_and(|c| c.is_uppercase()) {
        ItemKind::Type
    } else {
        ItemKind::Fn
    }
}

pub fn resolve_use_path(current: &[String], parts: &[String]) -> Vec<String> {
    let mut out = Vec::new();
    for (i, p) in parts.iter().enumerate() {
        match p.as_str() {
            "self" if i == 0 => out.extend(current.iter().cloned()),
            "crate" if i == 0 => {
                if let Some(root) = current.first() {
                    out.push(root.clone());
                }
            }
            "super" => {
                if i == 0 {
                    out.extend(current.iter().cloned());
                }
                out.pop();
            }
            _ => out.push(p.clone()),
        }
    }
    out
}
