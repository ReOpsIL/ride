use std::collections::HashSet;

use crate::extract::{CrateExtract, External, normalized};

use super::crates::extract_items;
use super::fingerprint::HashedCrate;

pub struct DeferredCrate {
    pub hash: String,
    pub crate_name: String,
    pub parts: CrateExtract,
}

#[derive(Default)]
pub struct Deferred {
    entries: Vec<DeferredCrate>,
    needed: HashSet<String>,
}

impl Deferred {
    pub fn unresolved_roots(&self, parts: &CrateExtract, external: &External) -> Vec<String> {
        parts
            .cross_crate_roots()
            .into_iter()
            .filter(|root| !external.has_root(root))
            .collect()
    }

    pub fn push(&mut self, hashed: &HashedCrate, parts: CrateExtract, roots: Vec<String>) {
        self.needed.extend(roots.iter().map(|r| normalized(r)));
        self.entries.push(DeferredCrate {
            hash: hashed.hash.clone(),
            crate_name: hashed.crate_.name.clone(),
            parts,
        });
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    pub fn targets<'a>(&self, hashed: &'a [HashedCrate]) -> Vec<&'a HashedCrate> {
        hashed
            .iter()
            .filter(|h| self.needed.contains(&normalized(&h.crate_.name)))
            .collect()
    }

    pub fn into_entries(self) -> Vec<DeferredCrate> {
        self.entries
    }
}

pub fn absorb_target(hashed: &HashedCrate, external: &mut External) {
    if let Ok(items) = extract_items(&hashed.crate_, external) {
        external.absorb(&items);
    }
}
