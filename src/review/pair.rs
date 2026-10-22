use std::collections::HashMap;

use super::checks;
use super::identity::ParsedItem;
use super::model::{Change, FileInput, Group, Hunks, LineRange, Row, module_of};

pub(crate) struct FileRows {
    pub rows: Vec<Row>,
    pub shapes: Vec<String>,
    pub defs: Vec<String>,
    pub items: Vec<ParsedItem>,
}

pub(crate) fn pair(file: &FileInput, old: Vec<ParsedItem>, new: Vec<ParsedItem>) -> FileRows {
    let shapes = old
        .iter()
        .chain(&new)
        .map(|item| item.shape.clone())
        .collect();
    let defs = new.iter().map(|item| item.name.clone()).collect();
    let items = new.clone();
    let mut rows = Vec::new();
    let mut old_map = group(old);
    let mut new_map = group(new);
    let mut keys: Vec<String> = old_map.keys().chain(new_map.keys()).cloned().collect();
    keys.sort();
    keys.dedup();
    let mut old_left = Vec::new();
    let mut new_left = Vec::new();
    for key in keys {
        let olds = old_map.remove(&key).unwrap_or_default();
        let news = new_map.remove(&key).unwrap_or_default();
        let shared = olds.len().min(news.len());
        for index in 0..shared {
            if let Some(row) = paired(&file.path, &olds[index], &news[index], file.hunks.as_ref()) {
                rows.push(row);
            }
        }
        old_left.extend(olds.into_iter().skip(shared));
        new_left.extend(news.into_iter().skip(shared));
    }
    overlap_pair(
        &file.path,
        &mut old_left,
        &mut new_left,
        file.hunks.as_ref(),
        &mut rows,
    );
    for item in old_left {
        rows.push(lone(&file.path, &item, Change::Removed));
    }
    for item in new_left {
        rows.push(lone(&file.path, &item, Change::Added));
    }
    FileRows {
        rows,
        shapes,
        defs,
        items,
    }
}

fn group(items: Vec<ParsedItem>) -> HashMap<String, Vec<ParsedItem>> {
    let mut map: HashMap<String, Vec<ParsedItem>> = HashMap::new();
    for item in items {
        map.entry(format!("{}|{}", item.item, item.kind))
            .or_default()
            .push(item);
    }
    map
}

fn paired(path: &str, old: &ParsedItem, new: &ParsedItem, hunks: Option<&Hunks>) -> Option<Row> {
    if old.shape == new.shape {
        if !touched(old, new, hunks) {
            return None;
        }
        return Some(make(path, new, Change::Body, Vec::new(), "formatting"));
    }
    let change = if old.signature != new.signature {
        Change::Signature
    } else {
        Change::Body
    };
    if old.code == new.code {
        return Some(make(path, new, change, Vec::new(), "doc"));
    }
    let lit = checks::lights(
        change,
        path,
        &new.signature,
        new.is_test,
        &old.scan,
        &new.scan,
    );
    Some(make(path, new, change, lit, ""))
}

fn overlap_pair(
    path: &str,
    old: &mut Vec<ParsedItem>,
    new: &mut Vec<ParsedItem>,
    hunks: Option<&Hunks>,
    rows: &mut Vec<Row>,
) {
    let mut used_old = vec![false; old.len()];
    let mut used_new = vec![false; new.len()];
    let mut pairs: Vec<(u32, usize, usize)> = Vec::new();
    for (old_index, old_item) in old.iter().enumerate() {
        for (new_index, new_item) in new.iter().enumerate() {
            if old_item.kind != new_item.kind {
                continue;
            }
            let shared = overlap(old_item.start, old_item.end, new_item.start, new_item.end);
            let smaller = (old_item.end - old_item.start)
                .min(new_item.end - new_item.start)
                .max(1);
            if shared.saturating_mul(2) >= smaller {
                pairs.push((shared, old_index, new_index));
            }
        }
    }
    pairs.sort_by_key(|pair| std::cmp::Reverse(pair.0));
    for (_, old_index, new_index) in pairs {
        if used_old[old_index] || used_new[new_index] {
            continue;
        }
        used_old[old_index] = true;
        used_new[new_index] = true;
        if let Some(row) = paired(path, &old[old_index], &new[new_index], hunks) {
            rows.push(row);
        }
    }
    *old = old
        .drain(..)
        .enumerate()
        .filter(|(index, _)| !used_old[*index])
        .map(|(_, item)| item)
        .collect();
    *new = new
        .drain(..)
        .enumerate()
        .filter(|(index, _)| !used_new[*index])
        .map(|(_, item)| item)
        .collect();
}

fn lone(path: &str, item: &ParsedItem, change: Change) -> Row {
    let (old_scan, new_scan) = match change {
        Change::Added => ("", item.scan.as_str()),
        _ => (item.scan.as_str(), ""),
    };
    let lit = checks::lights(
        change,
        path,
        &item.signature,
        item.is_test,
        old_scan,
        new_scan,
    );
    make(path, item, change, lit, "")
}

fn make(path: &str, item: &ParsedItem, change: Change, lit: Vec<String>, detail: &str) -> Row {
    Row {
        path: path.to_string(),
        old_path: String::new(),
        item: item.item.clone(),
        name: item.name.clone(),
        kind: item.kind.clone(),
        change,
        group: Group::Behaviour,
        checks: lit,
        shape: item.shape.clone(),
        start_byte: item.start,
        end_byte: item.end,
        line: item.line,
        signature: item.signature.clone(),
        doc: item.doc.clone(),
        module: module_of(path),
        callers: 0,
        detail: detail.to_string(),
        is_test: item.is_test,
        verified_fresh: false,
        open_suspect: false,
        open_question: false,
        mark: String::new(),
        mark_author: String::new(),
        mark_state: String::new(),
        mark_note: String::new(),
        mark_id: String::new(),
    }
}

fn touched(old: &ParsedItem, new: &ParsedItem, hunks: Option<&Hunks>) -> bool {
    let Some(hunks) = hunks else {
        return true;
    };
    spans_touch(old.line, old.end_line, &hunks.old)
        || spans_touch(new.line, new.end_line, &hunks.new)
}

fn spans_touch(start: u32, end: u32, ranges: &[LineRange]) -> bool {
    ranges
        .iter()
        .any(|range| overlaps_range(start, end, *range))
}

fn overlaps_range(start: u32, end: u32, range: LineRange) -> bool {
    if range.end < range.start {
        return range.start > 0 && range.start >= start && range.start <= end.saturating_add(1);
    }
    range.start <= end && range.end >= start
}

fn overlap(a0: u32, a1: u32, b0: u32, b1: u32) -> u32 {
    a1.min(b1).saturating_sub(a0.max(b0))
}
