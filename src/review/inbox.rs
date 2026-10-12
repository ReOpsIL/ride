use std::collections::HashMap;

use super::file;
use super::model::{Built, CallSite, Candidate, FileInput, Inbox};
use super::moves;
use super::order::{self, ORDER};
use super::rows::name_totals;

pub fn review_files(files: &[FileInput]) -> Built {
    let mut rows = Vec::new();
    let mut shapes = Vec::new();
    let mut calls = Vec::new();
    let mut defs: HashMap<String, u32> = HashMap::new();
    let mut items = Vec::new();
    for file in files {
        let classified = file::classify(file);
        rows.extend(classified.rows);
        shapes.extend(classified.shapes.iter().cloned());
        calls.extend(classified.calls);
        for name in classified.defs {
            *defs.entry(name).or_default() += 1;
        }
        items.extend(classified.items.into_iter().map(|item| Candidate {
            path: file.path.clone(),
            item: item.item,
            kind: item.kind,
            shape: item.shape,
            name: item.name,
            line: item.line,
        }));
    }
    let uses = name_totals(&calls);
    for row in &mut rows {
        let seen = uses.get(&row.name).copied().unwrap_or(0);
        let defined = defs.get(&row.name).copied().unwrap_or(0);
        row.callers = seen.saturating_sub(defined);
    }
    moves::prove(&mut rows, &shapes);
    let mut inbox = Inbox {
        base: String::new(),
        head: String::new(),
        upstream: String::new(),
        order: ORDER.to_string(),
        grouped: false,
        counts: Default::default(),
        rows,
    };
    order::apply(&mut inbox);
    Built {
        inbox,
        items,
        calls,
        shapes,
    }
}

pub fn callers_of(calls: &[CallSite], name: &str, path: &str, line: u32) -> Vec<CallSite> {
    calls
        .iter()
        .filter(|call| call.name == name && !(call.path == path && call.line == line))
        .cloned()
        .collect()
}
