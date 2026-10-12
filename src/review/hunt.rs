use std::fs;

use crate::git::Git;
use crate::highlight::{Lang, parse_source};

use super::identity::{self, calls_in};
use super::model::{Group, Row};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HuntHit {
    pub path: String,
    pub item: String,
    pub name: String,
    pub checks: u32,
    pub on_stack: bool,
    pub open_mark: bool,
}

pub fn rank(calls: &[String], rows: &[Row], stack: &[String]) -> Vec<HuntHit> {
    let mut hits: Vec<HuntHit> = rows
        .iter()
        .filter(|row| row.group == Group::Behaviour && calls.iter().any(|name| name == &row.name))
        .map(|row| HuntHit {
            path: row.path.clone(),
            item: row.item.clone(),
            name: row.name.clone(),
            checks: row.checks.len() as u32,
            on_stack: stack.iter().any(|name| name == &row.name),
            open_mark: row.open_suspect || row.open_question,
        })
        .collect();
    hits.sort_by(|left, right| {
        right
            .on_stack
            .cmp(&left.on_stack)
            .then(right.checks.cmp(&left.checks))
            .then(right.open_mark.cmp(&left.open_mark))
            .then(left.path.cmp(&right.path))
    });
    hits
}

pub fn test_calls(git: &Git, name: &str) -> Vec<String> {
    let pattern = format!("fn {name}");
    let Ok(out) = git.run_accepting(&["grep", "-l", "-F", &pattern, "--", "*.rs"], &[0, 1]) else {
        return Vec::new();
    };
    for path in out.stdout.lines().take(12) {
        let Ok(text) = fs::read_to_string(git.dir().join(path)) else {
            continue;
        };
        if Lang::recognized(Some(path)) != Some(Lang::Rust) {
            continue;
        }
        let Ok(parsed) = parse_source(Lang::Rust, &text) else {
            continue;
        };
        let items = identity::parse_items(path, Lang::Rust, &text, &parsed.outline, &parsed.leaves);
        if let Some(item) = items.iter().find(|item| item.name == name) {
            return calls_in(&parsed.leaves, item.start, item.end, name);
        }
    }
    Vec::new()
}
