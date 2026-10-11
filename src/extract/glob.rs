use std::collections::HashSet;

use crate::ffi::ItemKind;

use super::crate_names::{root_of, same_crate};
use super::external::External;
use super::item::{ItemDoc, Visibility, join_path};
use super::reexport::{Reexport, dealias, exported};

pub const GLOB_LIMIT: usize = 20_000;

#[derive(Default)]
pub struct Globbed {
    pub items: Vec<ItemDoc>,
    pub oversized: Option<OversizedGlob>,
}

pub struct OversizedGlob {
    pub target: String,
    pub module: String,
}

pub fn expand(
    items: &[ItemDoc],
    extra: &[ItemDoc],
    external: &External,
    aliases: &[(String, String)],
    re: &Reexport,
    module: &[String],
) -> Globbed {
    let local = local_children(items, extra, re, module);
    let target = dealias(module, aliases);
    if !exported(re) || same_crate(root_of(&target), host_crate(items)) {
        return Globbed {
            items: local,
            oversized: None,
        };
    }
    match external.under_prefix(&target, GLOB_LIMIT) {
        Some(found) => {
            let mut out = local;
            out.extend(
                found
                    .into_iter()
                    .map(|src| mirror(items, src, re, &rerooted(re, &target, &src.path))),
            );
            Globbed {
                items: out,
                oversized: None,
            }
        }
        None => Globbed {
            items: Vec::new(),
            oversized: Some(OversizedGlob {
                target,
                module: re.module_path.join("::"),
            }),
        },
    }
}

fn local_children(
    items: &[ItemDoc],
    extra: &[ItemDoc],
    re: &Reexport,
    module: &[String],
) -> Vec<ItemDoc> {
    let prefix = format!("{}::", module.join("::"));
    let depth = module.len() + 1;
    items
        .iter()
        .chain(extra.iter())
        .filter(|i| {
            i.visibility == Visibility::Pub
                && i.path.starts_with(&prefix)
                && i.path.split("::").count() == depth
        })
        .map(|src| mirror(items, src, re, &join_path(&re.module_path, &src.name)))
        .collect()
}

pub(super) fn mirror(items: &[ItemDoc], src: &ItemDoc, re: &Reexport, path: &str) -> ItemDoc {
    let mut doc = src.clone();
    doc.path = path.to_string();
    doc.visibility = re.vis;
    doc.reachable = exported(re);
    if let Some(host) = items.first() {
        doc.crate_name = host.crate_name.clone();
        doc.crate_version = host.crate_version.clone();
        doc.edition = host.edition.clone();
        doc.scope = host.scope;
    }
    doc
}

pub(super) fn descendants(
    items: &[ItemDoc],
    extra: &[ItemDoc],
    external: &External,
    re: &Reexport,
    kind: ItemKind,
    origin: &str,
    alias: &str,
) -> Globbed {
    if !has_children(kind) {
        return Globbed::default();
    }
    let prefix = format!("{origin}::");
    let dest = join_path(&re.module_path, alias);
    let mut gather = Gather::new(prefix);
    if !gather.take_all(items.iter().chain(extra.iter())) {
        return oversized(origin, re);
    }
    match external.under_prefix(origin, GLOB_LIMIT) {
        None => return oversized(origin, re),
        Some(remote) => {
            if !gather.take_all(remote.into_iter()) {
                return oversized(origin, re);
            }
        }
    }
    Globbed {
        items: gather.finish(items, re, &dest),
        oversized: None,
    }
}

struct Gather {
    prefix: String,
    seen: HashSet<String>,
    found: Vec<ItemDoc>,
}

impl Gather {
    fn new(prefix: String) -> Self {
        Self {
            prefix,
            seen: HashSet::new(),
            found: Vec::new(),
        }
    }

    fn take_all<'a>(&mut self, sources: impl Iterator<Item = &'a ItemDoc>) -> bool {
        for src in sources {
            if !self.take(src) {
                return false;
            }
        }
        true
    }

    fn take(&mut self, src: &ItemDoc) -> bool {
        if src.visibility != Visibility::Pub || !src.path.starts_with(&self.prefix) {
            return true;
        }
        if !self.seen.insert(src.path.clone()) {
            return true;
        }
        if self.found.len() == GLOB_LIMIT {
            return false;
        }
        self.found.push(src.clone());
        true
    }

    fn finish(self, items: &[ItemDoc], re: &Reexport, dest: &str) -> Vec<ItemDoc> {
        let prefix_len = self.prefix.len();
        self.found
            .into_iter()
            .map(|src| {
                let rest = src.path[prefix_len..].to_string();
                mirror(items, &src, re, &format!("{dest}::{rest}"))
            })
            .collect()
    }
}

fn has_children(kind: ItemKind) -> bool {
    matches!(
        kind,
        ItemKind::Mod | ItemKind::Struct | ItemKind::Enum | ItemKind::Union | ItemKind::Trait
    )
}

fn oversized(origin: &str, re: &Reexport) -> Globbed {
    Globbed {
        items: Vec::new(),
        oversized: Some(OversizedGlob {
            target: origin.to_string(),
            module: re.module_path.join("::"),
        }),
    }
}

fn rerooted(re: &Reexport, target: &str, path: &str) -> String {
    let rest = path.get(target.len() + 2..).unwrap_or_default();
    format!("{}::{rest}", re.module_path.join("::"))
}

fn host_crate(items: &[ItemDoc]) -> &str {
    items.first().map(|i| i.crate_name.as_str()).unwrap_or("")
}
