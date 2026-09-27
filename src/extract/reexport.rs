use std::path::PathBuf;

use crate::ffi::ItemKind;

use super::external::External;
use super::glob::{self, OversizedGlob};
use super::item::{ItemDoc, Scope, Visibility, join_path};
use super::path_index::PathIndex;

#[derive(Debug, Clone)]
pub struct Reexport {
    pub module_path: Vec<String>,
    pub vis: Visibility,
    pub reach: bool,
    pub source_path: PathBuf,
    pub byte_range: (u32, u32),
    pub kind: ReexportKind,
}

#[derive(Debug, Clone)]
pub enum ReexportKind {
    Named { target: Vec<String>, alias: String },
    Glob { module: Vec<String> },
}

#[derive(Default)]
pub struct Applied {
    pub items: Vec<ItemDoc>,
    pub oversized_globs: Vec<OversizedGlob>,
}

struct Resolver<'a> {
    items: &'a [ItemDoc],
    external: &'a External,
    aliases: &'a [(String, String)],
    index: PathIndex<'a>,
    applied: Applied,
}

pub fn apply(
    items: &[ItemDoc],
    reexports: &[Reexport],
    external: &External,
    aliases: &[(String, String)],
) -> Applied {
    let mut resolver = Resolver {
        items,
        external,
        aliases,
        index: PathIndex::new(items),
        applied: Applied::default(),
    };
    let mut pending: Vec<&Reexport> = reexports.iter().collect();
    for _ in 0..3 {
        let before = pending.len();
        pending = resolver.pass(pending);
        if pending.is_empty() || pending.len() == before {
            break;
        }
    }
    resolver.settle(pending);
    resolver.applied
}

impl<'a> Resolver<'a> {
    fn pass<'r>(&mut self, pending: Vec<&'r Reexport>) -> Vec<&'r Reexport> {
        let mut next = Vec::new();
        for re in pending {
            match &re.kind {
                ReexportKind::Glob { module } => self.expand(re, module),
                ReexportKind::Named { target, alias } => {
                    let extra = &self.applied.items;
                    let found = self.index.find(extra, &re.module_path, target);
                    match found.map(|src| remap(self.items, src, re, alias)) {
                        Some(doc) => self.applied.items.push(doc),
                        None => next.push(re),
                    }
                }
            }
            self.index.sync(&self.applied.items);
        }
        next
    }

    fn expand(&mut self, re: &Reexport, module: &[String]) {
        let extra = &self.applied.items;
        let found = glob::expand(self.items, extra, self.external, self.aliases, re, module);
        self.applied.items.extend(found.items);
        self.applied.oversized_globs.extend(found.oversized);
    }

    fn settle(&mut self, pending: Vec<&Reexport>) {
        for re in pending {
            if let ReexportKind::Named { target, alias } = &re.kind {
                let doc = match self.external.get(&dealias(target, self.aliases)) {
                    Some(src) => remap(self.items, src, re, alias),
                    None => unresolved(self.items, re, alias),
                };
                self.applied.items.push(doc);
            }
        }
    }
}

fn remap(items: &[ItemDoc], src: &ItemDoc, re: &Reexport, alias: &str) -> ItemDoc {
    let mut doc = glob::mirror(items, src, re, &join_path(&re.module_path, alias));
    doc.name = alias.to_string();
    doc
}

pub(super) fn dealias(target: &[String], aliases: &[(String, String)]) -> String {
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
        source_path: re.source_path.clone(),
        byte_range: re.byte_range,
        name_start_byte: re.byte_range.0,
        edition: items.first().and_then(|i| i.edition.clone()),
        features: Vec::new(),
        visibility: re.vis,
        scope: items.first().map(|i| i.scope).unwrap_or(Scope::Cache),
        reachable: exported(re),
        deprecated: false,
    }
}

pub(super) fn exported(re: &Reexport) -> bool {
    re.reach && re.vis == Visibility::Pub
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
