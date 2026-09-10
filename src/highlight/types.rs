use std::collections::HashMap;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use tree_sitter::Tree;

use crate::ffi::OutlineItem;

use super::members::Chain;
use super::type_lookup;

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct TypeTable {
    origin: Option<PathBuf>,
    members: HashMap<String, Vec<OutlineItem>>,
    member_types: HashMap<String, HashMap<String, String>>,
    scopes: HashMap<String, Vec<OutlineItem>>,
    functions: HashMap<String, String>,
    bases: HashMap<String, Vec<String>>,
    aliases: HashMap<String, String>,
}

#[derive(Debug, Clone)]
pub struct Member {
    pub item: OutlineItem,
    pub origin: Option<PathBuf>,
    pub type_name: Option<String>,
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

    pub fn add_scope(&mut self, path: String, items: Vec<OutlineItem>) {
        self.scopes.entry(path).or_default().extend(items);
    }

    pub fn add_function(&mut self, name: String, returns: String) {
        self.functions.entry(name).or_insert(returns);
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
        self.members.is_empty() && self.aliases.is_empty() && self.scopes.is_empty()
    }

    pub fn resolve(tables: &[&TypeTable], name: &str) -> Vec<Member> {
        type_lookup::resolve(tables, name)
    }

    pub fn scoped(tables: &[&TypeTable], segments: &[String]) -> Vec<Member> {
        type_lookup::scoped(tables, segments)
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

    pub(super) fn scope(&self, path: &str) -> Option<&Vec<OutlineItem>> {
        self.scopes.get(path)
    }

    pub(super) fn function(&self, name: &str) -> Option<&String> {
        self.functions.get(name)
    }

    pub(super) fn bases_of(&self, name: &str) -> Option<&Vec<String>> {
        self.bases.get(name)
    }

    pub(super) fn alias_of(&self, name: &str) -> Option<&String> {
        self.aliases.get(name)
    }
}

pub fn empty_table(_: &Tree, _: &str) -> TypeTable {
    TypeTable::default()
}
