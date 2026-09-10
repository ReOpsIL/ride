use std::collections::HashSet;

use super::members::{Chain, Root, Step};
use super::types::{Member, TypeTable};

const MAX_DEPTH: usize = 6;

pub fn resolve(tables: &[&TypeTable], name: &str) -> Vec<Member> {
    let mut out = Vec::new();
    let mut seen = HashSet::new();
    collect(tables, name, 0, &mut seen, &mut out);
    out
}

pub fn scoped(tables: &[&TypeTable], segments: &[String]) -> Vec<Member> {
    let mut segs: Vec<String> = segments.to_vec();
    if let Some(first) = segs.first()
        && let Some(target) = tables.iter().find_map(|t| t.alias_of(first))
    {
        segs.splice(0..1, target.split("::").map(str::to_string));
    }
    let path = segs.join("::");
    let mut out = Vec::new();
    for table in tables {
        if let Some(items) = table.scope(&path) {
            out.extend(items.iter().map(|item| member(table, item, None)));
        }
    }
    if out.is_empty()
        && let Some(last) = segs.last()
    {
        out = resolve(tables, last);
    }
    out
}

pub fn follow(tables: &[&TypeTable], chain: &Chain) -> Option<String> {
    let mut current = match &chain.root {
        Root::Type(name) => name.clone(),
        Root::Call(name) => tables.iter().find_map(|t| t.function(name))?.clone(),
    };
    for step in &chain.steps {
        let member = match step {
            Step::Field(name) | Step::Call(name) => name,
        };
        current = resolve(tables, &current)
            .into_iter()
            .find(|m| m.item.name == *member && m.type_name.is_some())?
            .type_name?;
    }
    Some(current)
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
        if let Some(target) = table.alias_of(name) {
            collect(tables, target, depth + 1, seen, out);
        }
    }
    for table in tables {
        if let Some(items) = table.members_of(name) {
            out.extend(items.iter().map(|item| {
                let mut m = member(table, item, table.member_type(name, &item.name));
                m.detail = table
                    .member_detail(name, &item.name)
                    .cloned()
                    .or_else(|| m.type_name.clone())
                    .unwrap_or_default();
                m
            }));
        }
        if let Some(bases) = table.bases_of(name) {
            for base in bases {
                collect(tables, base, depth + 1, seen, out);
            }
        }
    }
}

fn member(table: &TypeTable, item: &crate::ffi::OutlineItem, type_name: Option<&String>) -> Member {
    Member {
        item: item.clone(),
        origin: table.origin().cloned(),
        type_name: type_name.cloned(),
        detail: String::new(),
    }
}
