use std::cmp::Reverse;
use std::collections::HashMap;

use super::model::{Change, Counts, Group, Inbox, Row};

pub const ORDER: &str = "sorted by checks, then callers by name, then path";

pub fn apply(inbox: &mut Inbox) {
    assign_groups(&mut inbox.rows);
    let behaviour = inbox
        .rows
        .iter()
        .filter(|row| row.group == Group::Behaviour)
        .count();
    inbox.grouped = behaviour > 20;
    sort_rows(&mut inbox.rows, inbox.grouped);
    inbox.counts = counts(&inbox.rows);
    inbox.order = ORDER.to_string();
}

fn assign_groups(rows: &mut [Row]) {
    for row in rows {
        if row.change == Change::Moved || row.detail == "formatting" {
            row.group = Group::Equivalent;
            row.checks.clear();
            continue;
        }
        if row.detail == "doc" || row.detail == "import" {
            row.group = Group::Light;
            continue;
        }
        if row.is_test && row.checks.is_empty() && row.change != Change::File {
            row.group = Group::Light;
            if row.detail.is_empty() {
                row.detail = "test".to_string();
            }
            continue;
        }
        if row.group != Group::Light {
            row.group = Group::Behaviour;
        }
    }
}

fn sort_rows(rows: &mut [Row], grouped: bool) {
    let module_rank = module_ranks(rows, grouped);
    rows.sort_by(|left, right| {
        key(left, grouped, &module_rank).cmp(&key(right, grouped, &module_rank))
    });
}

fn key<'a>(
    row: &'a Row,
    grouped: bool,
    ranks: &HashMap<String, u32>,
) -> (u8, u8, u32, Reverse<usize>, Reverse<u32>, &'a str, &'a str) {
    let stale = u8::from(row.mark_state != "stale");
    let rank = if grouped && row.group == Group::Behaviour {
        ranks.get(&row.module).copied().unwrap_or(u32::MAX)
    } else {
        0
    };
    (
        row.group.rank(),
        stale,
        rank,
        Reverse(row.checks.len()),
        Reverse(row.callers),
        row.path.as_str(),
        row.item.as_str(),
    )
}

fn module_ranks(rows: &[Row], grouped: bool) -> HashMap<String, u32> {
    if !grouped {
        return HashMap::new();
    }
    let mut best: HashMap<String, usize> = HashMap::new();
    for row in rows.iter().filter(|row| row.group == Group::Behaviour) {
        let slot = best.entry(row.module.clone()).or_insert(0);
        *slot = (*slot).max(row.checks.len());
    }
    let mut modules: Vec<(String, usize)> = best.into_iter().collect();
    modules.sort_by(|left, right| right.1.cmp(&left.1).then(left.0.cmp(&right.0)));
    modules
        .into_iter()
        .enumerate()
        .map(|(index, (module, _))| (module, index as u32))
        .collect()
}

pub fn counts(rows: &[Row]) -> Counts {
    let mut counts = Counts::default();
    for row in rows {
        match row.group {
            Group::Behaviour => counts.behaviour += 1,
            Group::Light => {
                counts.light += 1;
                match row.detail.as_str() {
                    "doc" => counts.docs += 1,
                    "import" => counts.imports += 1,
                    "test" => counts.tests += 1,
                    _ => {}
                }
            }
            Group::Equivalent => {
                counts.equivalent += 1;
                if row.change == Change::Moved {
                    counts.moved += 1;
                } else {
                    counts.formatting += 1;
                }
            }
        }
        if row.group == Group::Equivalent {
            continue;
        }
        if row.verified_fresh {
            counts.verified += 1;
        }
        if row.open_suspect {
            counts.suspect += 1;
        }
        if row.open_question {
            counts.question += 1;
        }
    }
    counts.needs_eyes = counts.behaviour + counts.light;
    let covered = rows
        .iter()
        .filter(|row| row.group != Group::Equivalent && row.covered())
        .count() as u32;
    counts.unchecked = counts.needs_eyes.saturating_sub(covered);
    counts
}
