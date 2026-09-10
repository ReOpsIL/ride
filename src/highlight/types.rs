use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use tree_sitter::Tree;

use crate::ffi::OutlineItem;

const MAX_DEPTH: usize = 6;

#[derive(Debug, Default, Clone)]
pub struct TypeTable {
    origin: Option<PathBuf>,
    members: HashMap<String, Vec<OutlineItem>>,
    bases: HashMap<String, Vec<String>>,
    aliases: HashMap<String, String>,
}

#[derive(Debug, Clone)]
pub struct Member {
    pub item: OutlineItem,
    pub origin: Option<PathBuf>,
}

impl TypeTable {
    pub fn with_origin(mut self, origin: &Path) -> Self {
        self.origin = Some(origin.to_path_buf());
        self
    }

    pub fn add_members(&mut self, name: String, items: Vec<OutlineItem>) {
        self.members.entry(name).or_default().extend(items);
    }

    pub fn add_bases(&mut self, name: String, bases: Vec<String>) {
        if !bases.is_empty() {
            self.bases.insert(name, bases);
        }
    }

    pub fn add_alias(&mut self, alias: String, target: String) {
        if alias != target {
            self.aliases.insert(alias, target);
        }
    }

    pub fn is_empty(&self) -> bool {
        self.members.is_empty() && self.aliases.is_empty()
    }

    pub fn resolve(tables: &[&TypeTable], name: &str) -> Vec<Member> {
        let mut out = Vec::new();
        let mut seen = HashSet::new();
        collect(tables, name, 0, &mut seen, &mut out);
        out
    }
}

pub fn empty_table(_: &Tree, _: &str) -> TypeTable {
    TypeTable::default()
}

fn collect(
    tables: &[&TypeTable],
    name: &str,
    depth: usize,
    seen: &mut HashSet<String>,
    out: &mut Vec<Member>,
) {
    if depth > MAX_DEPTH || !seen.insert(name.to_string()) {
        return;
    }
    for table in tables {
        if let Some(target) = table.aliases.get(name) {
            collect(tables, target, depth + 1, seen, out);
        }
    }
    for table in tables {
        if let Some(items) = table.members.get(name) {
            out.extend(items.iter().map(|item| Member {
                item: item.clone(),
                origin: table.origin.clone(),
            }));
        }
        if let Some(bases) = table.bases.get(name) {
            for base in bases {
                collect(tables, base, depth + 1, seen, out);
            }
        }
    }
}
