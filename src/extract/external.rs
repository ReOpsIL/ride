use std::collections::{HashMap, HashSet};

use super::crate_extract::normalized;
use super::item::{ItemDoc, Visibility};

#[derive(Default)]
pub struct External {
    by_path: HashMap<String, ItemDoc>,
    roots: HashSet<String>,
}

impl External {
    pub fn absorb(&mut self, items: &[ItemDoc]) {
        for item in items.iter().filter(|i| i.visibility == Visibility::Pub) {
            self.roots.insert(normalized(root_of(&item.path)));
            self.by_path
                .entry(item.path.clone())
                .or_insert_with(|| item.clone());
        }
    }

    pub fn get(&self, path: &str) -> Option<&ItemDoc> {
        self.by_path.get(path)
    }

    pub fn has_root(&self, root: &str) -> bool {
        self.roots.contains(&normalized(root))
    }

    pub fn under_prefix(&self, prefix: &str, limit: usize) -> Option<Vec<&ItemDoc>> {
        let pat = format!("{prefix}::");
        let mut found = Vec::new();
        for item in self.by_path.values().filter(|i| i.path.starts_with(&pat)) {
            if found.len() == limit {
                return None;
            }
            found.push(item);
        }
        Some(found)
    }

    pub fn len(&self) -> usize {
        self.by_path.len()
    }

    pub fn is_empty(&self) -> bool {
        self.by_path.is_empty()
    }
}

fn root_of(path: &str) -> &str {
    path.split("::").next().unwrap_or(path)
}
