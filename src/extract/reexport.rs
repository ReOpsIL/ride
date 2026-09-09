use std::path::PathBuf;

use crate::ffi::ItemKind;

use super::external::External;
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

pub fn apply(
    items: &[ItemDoc],
    reexports: &[Reexport],
    external: &External,
    aliases: &[(String, String)],
) -> Vec<ItemDoc> {
    let mut extra: Vec<ItemDoc> = Vec::new();
    let mut pending: Vec<&Reexport> = reexports.iter().collect();
    for _ in 0..3 {
        let before = pending.len();
        let mut next = Vec::new();
        for re in pending.drain(..) {
            match &re.kind {
                ReexportKind::Glob { module } => {
                    let found = glob(items, &extra, re, module);
                    extra.extend(found);
                }
                ReexportKind::Named { target, alias } => {
                    match find_target(items, &extra, &re.module_path, target) {
                        Some(src) => extra.push(remap(items, src, re, alias)),
                        None => next.push(re),
                    }
                }
            }
        }
        pending = next;
        if pending.is_empty() || pending.len() == before {
            break;
        }
    }
    for re in pending {
        if let ReexportKind::Named { target, alias } = &re.kind {
            extra.push(match external.get(&dealias(target, aliases)) {
                Some(src) => remap(items, src, re, alias),
                None => unresolved(items, re, alias),
            });
        }
    }
    extra
}

fn remap(items: &[ItemDoc], src: &ItemDoc, re: &Reexport, alias: &str) -> ItemDoc {
    let mut doc = src.clone();
    doc.path = join_path(&re.module_path, alias);
    doc.name = alias.to_string();
    doc.visibility = re.vis;
    if let Some(host) = items.first() {
        doc.crate_name = host.crate_name.clone();
        doc.crate_version = host.crate_version.clone();
        doc.edition = host.edition.clone();
        doc.scope = host.scope;
    }
    doc
}

fn dealias(target: &[String], aliases: &[(String, String)]) -> String {
    let mut parts = target.to_vec();
    if let Some(first) = parts.first_mut()
        && let Some((_, real)) = aliases.iter().find(|(alias, _)| alias == first)
    {
        *first = real.clone();
    }
    parts.join("::")
}

fn unresolved(items: &[ItemDoc], re: &Reexport, alias: &str) -> ItemDoc {
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
        path: join_path(&re.module_path, alias),
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

fn find_target<'a>(
    items: &'a [ItemDoc],
    extra: &'a [ItemDoc],
    module: &[String],
    target: &[String],
) -> Option<&'a ItemDoc> {
    let joined = target.join("::");
    let relative = join_path(module, &joined);
    let from_root = module.first().map(|root| format!("{root}::{joined}"));
    let matches = |i: &&ItemDoc| {
        i.path == joined || i.path == relative || from_root.as_deref() == Some(i.path.as_str())
    };
    items
        .iter()
        .find(matches)
        .or_else(|| extra.iter().find(matches))
}

fn glob(items: &[ItemDoc], extra: &[ItemDoc], re: &Reexport, module: &[String]) -> Vec<ItemDoc> {
    let prefix = module.join("::");
    let depth = module.len() + 1;
    items
        .iter()
        .chain(extra.iter())
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
