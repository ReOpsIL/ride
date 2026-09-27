use std::collections::HashMap;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use tree_sitter::Tree;

use crate::ffi::OutlineItem;

use super::members::Chain;
use super::type_lookup;
use super::type_relations::Relations;
use super::visibility::{Unqualified, Visibility};

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct TypeTable {
    origin: Option<PathBuf>,
    members: HashMap<String, Vec<OutlineItem>>,
    member_types: HashMap<String, HashMap<String, String>>,
    member_details: HashMap<String, HashMap<String, String>>,
    scopes: HashMap<String, Vec<OutlineItem>>,
    functions: HashMap<String, String>,
    #[serde(default)]
    relations: Relations,
    aliases: HashMap<String, String>,
    #[serde(default)]
    unqualified: HashMap<String, Vec<Unqualified>>,
}

#[derive(Debug, Clone)]
pub struct Member {
    pub item: OutlineItem,
    pub origin: Option<PathBuf>,
    pub type_name: Option<String>,
    pub detail: String,
}

impl TypeTable {
    pub fn with_origin(mut self, origin: &Path) -> Self {
        self.origin = Some(origin.to_path_buf());
        self
    }

    pub fn add_members(&mut self, name: String, items: Vec<OutlineItem>) {
        self.members.entry(name).or_default().extend(items);
    }

    pub fn add_member_types(&mut self, name: String, types: Vec<(String, String)>) {
        if !types.is_empty() {
            self.member_types.entry(name).or_default().extend(types);
        }
    }

    pub fn add_member_details(&mut self, name: String, details: Vec<(String, String)>) {
        if !details.is_empty() {
            self.member_details.entry(name).or_default().extend(details);
        }
    }

    pub fn add_unqualified(&mut self, item: OutlineItem, visibility: Visibility) {
        let entries = self.unqualified.entry(item.name.clone()).or_default();
        if !entries
            .iter()
            .any(|e| e.item.name_start_byte == item.name_start_byte && e.visibility == visibility)
        {
            entries.push(Unqualified { item, visibility });
        }
    }

    pub fn relations(&self) -> &Relations {
        &self.relations
    }

    pub fn relations_mut(&mut self) -> &mut Relations {
        &mut self.relations
    }

    pub fn defines(&self, name: &str) -> bool {
        self.members.contains_key(name)
    }

    pub fn add_scope(&mut self, path: String, items: Vec<OutlineItem>) {
        self.scopes.entry(path).or_default().extend(items);
    }

    pub fn add_function(&mut self, name: String, returns: String) {
        self.functions.entry(name).or_insert(returns);
    }

    pub fn add_alias(&mut self, alias: String, target: String) {
        if alias != target {
            self.aliases.insert(alias, target);
        }
    }

    pub fn resolve(tables: &[&TypeTable], name: &str) -> Vec<Member> {
        type_lookup::resolve(tables, name)
    }

    pub fn scoped(tables: &[&TypeTable], segments: &[String]) -> Vec<Member> {
        type_lookup::scoped(tables, segments)
    }

    pub fn unqualified(tables: &[&TypeTable], name: &str, at: u32) -> Vec<Member> {
        type_lookup::unqualified(tables, name, at)
    }

    pub fn declared_at(&self, name_start_byte: u32) -> Option<Member> {
        type_lookup::declared_at(self, name_start_byte)
    }

    pub fn own_members(&self, name: &str) -> Vec<Member> {
        let Some(items) = self.members_of(name) else {
            return Vec::new();
        };
        items
            .iter()
            .map(|item| {
                let type_name = self.member_type(name, &item.name).cloned();
                let detail = self
                    .member_detail(name, &item.name)
                    .cloned()
                    .or_else(|| type_name.clone())
                    .unwrap_or_default();
                Member {
                    item: item.clone(),
                    origin: self.origin.clone(),
                    type_name,
                    detail,
                }
            })
            .collect()
    }

    pub fn follow(tables: &[&TypeTable], chain: &Chain) -> Option<String> {
        type_lookup::follow(tables, chain)
    }

    pub(super) fn origin(&self) -> Option<&PathBuf> {
        self.origin.as_ref()
    }

    pub(super) fn members_of(&self, name: &str) -> Option<&Vec<OutlineItem>> {
        self.members.get(name)
    }

    pub(super) fn member_type(&self, type_name: &str, member: &str) -> Option<&String> {
        self.member_types.get(type_name)?.get(member)
    }

    pub(super) fn member_detail(&self, type_name: &str, member: &str) -> Option<&String> {
        self.member_details.get(type_name)?.get(member)
    }

    pub(super) fn all_members(&self) -> impl Iterator<Item = &OutlineItem> {
        self.members.values().flatten()
    }

    pub(super) fn unqualified_named(&self, name: &str) -> &[Unqualified] {
        self.unqualified.get(name).map_or(&[], Vec::as_slice)
    }

    pub(super) fn scope(&self, path: &str) -> Option<&Vec<OutlineItem>> {
        self.scopes.get(path)
    }

    pub(super) fn function(&self, name: &str) -> Option<&String> {
        self.functions.get(name)
    }

    pub(super) fn alias_of(&self, name: &str) -> Option<&String> {
        self.aliases.get(name)
    }
}

pub fn empty_table(_: &Tree, _: &str) -> TypeTable {
    TypeTable::default()
}
