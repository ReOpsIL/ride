use std::path::Path;

use crate::ffi::ItemKind;

use super::cargo_toml::Package;
use super::external::External;
use super::glob::OversizedGlob;
use super::item::{CrateContext, ItemDoc, ItemParts, Scope, Visibility};
use super::reach::{self, Assoc};
use super::reexport::{self, Reexport, ReexportKind, dealias};

pub struct CrateExtract {
    pub(super) name: String,
    pub(super) scope: Scope,
    pub(super) items: Vec<ItemDoc>,
    pub(super) reexports: Vec<Reexport>,
    pub(super) aliases: Vec<(String, String)>,
    pub(super) assoc: Vec<Assoc>,
}

pub struct CrateItems {
    pub items: Vec<ItemDoc>,
    pub oversized_globs: Vec<OversizedGlob>,
}

impl CrateExtract {
    pub fn cross_crate_roots(&self) -> Vec<String> {
        let globs: Vec<String> = self.foreign_roots(true);
        if globs.is_empty() {
            return globs;
        }
        let mut roots = globs;
        roots.extend(self.foreign_roots(false));
        roots.sort();
        roots.dedup();
        roots
    }

    pub fn finish(mut self, external: &External) -> CrateItems {
        let applied = reexport::apply(&self.items, &self.reexports, external, &self.aliases);
        self.items.extend(applied.items);
        reach::resolve(&mut self.items, &self.assoc, self.scope);
        CrateItems {
            items: self.items,
            oversized_globs: applied.oversized_globs,
        }
    }

    fn foreign_roots(&self, globs: bool) -> Vec<String> {
        self.reexports
            .iter()
            .filter_map(|re| match (&re.kind, globs) {
                (ReexportKind::Glob { module }, true) => Some(module),
                (ReexportKind::Named { target, .. }, false) => Some(target),
                _ => None,
            })
            .map(|path| root_of(&dealias(path, &self.aliases)).to_string())
            .filter(|root| normalized(root) != normalized(&self.name))
            .collect()
    }
}

pub fn plain(items: Vec<ItemDoc>, name: String, scope: Scope) -> CrateExtract {
    CrateExtract {
        name,
        scope,
        items,
        reexports: Vec::new(),
        aliases: Vec::new(),
        assoc: Vec::new(),
    }
}

pub fn crate_item(pkg: &Package, crate_root: &Path, ctx: &CrateContext) -> ItemDoc {
    ItemDoc::from_ctx(
        ctx,
        ItemParts {
            kind: ItemKind::Crate,
            path: pkg.name.clone(),
            name: pkg.name.clone(),
            vis: Visibility::Pub,
            source_path: crate_root.join("Cargo.toml"),
            byte_range: (0, 0),
            name_start_byte: 0,
            signature: String::new(),
            doc: pkg.description.clone().unwrap_or_default(),
            chunk: String::new(),
            reachable: true,
            deprecated: false,
        },
    )
}

pub fn normalized(name: &str) -> String {
    name.replace('-', "_")
}

fn root_of(path: &str) -> &str {
    path.split("::").next().unwrap_or(path)
}
