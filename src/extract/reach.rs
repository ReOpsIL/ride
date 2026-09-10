use std::collections::{HashMap, HashSet};

use crate::ffi::ItemKind;

use super::item::{ItemDoc, Scope, Visibility};

pub struct Assoc {
    pub path: String,
    pub owner: String,
}

pub fn resolve(items: &mut [ItemDoc], assoc: &[Assoc], scope: Scope) {
    if scope == Scope::Workspace {
        for item in items.iter_mut() {
            item.reachable = true;
        }
        return;
    }
    let owner_of: HashMap<&str, &str> = assoc
        .iter()
        .map(|a| (a.path.as_str(), last_segment(&a.owner)))
        .collect();
    let owners = owner_reach(items, &owner_of);
    for item in items.iter_mut() {
        let Some(owner) = owner_of.get(item.path.as_str()) else {
            continue;
        };
        if let Some(reach) = owners.get(*owner) {
            item.reachable = *reach && item.visibility == Visibility::Pub;
        }
    }
}

fn owner_reach(items: &[ItemDoc], owner_of: &HashMap<&str, &str>) -> HashMap<String, bool> {
    let assoc_paths: HashSet<&str> = owner_of.keys().copied().collect();
    let mut owners: HashMap<String, bool> = HashMap::new();
    for item in items
        .iter()
        .filter(|i| is_owner_kind(i.item_kind) && !assoc_paths.contains(i.path.as_str()))
    {
        let entry = owners
            .entry(last_segment(&item.path).to_string())
            .or_insert(false);
        *entry |= item.reachable;
    }
    owners
}

fn is_owner_kind(kind: ItemKind) -> bool {
    matches!(
        kind,
        ItemKind::Struct | ItemKind::Enum | ItemKind::Union | ItemKind::Trait | ItemKind::Type
    )
}

fn last_segment(path: &str) -> &str {
    path.rsplit("::").next().unwrap_or(path)
}
