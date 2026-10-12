use std::collections::HashMap;

use super::model::{CallSite, Change, Group, Row, module_of};

pub fn light(path: &str, kind: &str, name: &str, detail: &str) -> Row {
    let mut row = plain(path, name, kind, Change::Body, detail);
    row.group = Group::Light;
    row
}

pub fn plain(path: &str, name: &str, kind: &str, change: Change, detail: &str) -> Row {
    Row {
        path: path.to_string(),
        old_path: String::new(),
        item: name.to_string(),
        name: name.to_string(),
        kind: kind.to_string(),
        change,
        group: Group::Behaviour,
        checks: Vec::new(),
        shape: String::new(),
        start_byte: 0,
        end_byte: 0,
        line: 1,
        signature: String::new(),
        doc: String::new(),
        module: module_of(path),
        callers: 0,
        detail: detail.to_string(),
        is_test: false,
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

pub fn name_totals(calls: &[CallSite]) -> HashMap<String, u32> {
    let mut totals = HashMap::new();
    for call in calls {
        *totals.entry(call.name.clone()).or_default() += 1;
    }
    totals
}
