use std::collections::HashMap;

use crate::review::{Candidate, Inbox, finish};

use super::mark::Mark;
use super::state::{derive, locate};

pub fn attach(inbox: &mut Inbox, marks: &[Mark], items: &[Candidate]) {
    for row in &mut inbox.rows {
        row.verified_fresh = false;
        row.open_suspect = false;
        row.open_question = false;
        row.mark.clear();
        row.mark_author.clear();
        row.mark_state.clear();
        row.mark_note.clear();
        row.mark_id.clear();
    }
    let mut best: HashMap<usize, (u8, usize, String)> = HashMap::new();
    for (mark_index, mark) in marks.iter().enumerate() {
        let state = derive(mark, items);
        let Some(target) = locate(mark, items, state) else {
            continue;
        };
        let Some(row_index) = inbox.rows.iter().position(|row| {
            row.path == target.path && row.item == target.item && row.kind == target.kind
        }) else {
            continue;
        };
        if !mark.agent {
            let row = &mut inbox.rows[row_index];
            if mark.mark == "verified" && state == "fresh" {
                row.verified_fresh = true;
            }
            if mark.mark == "suspect" {
                row.open_suspect = true;
            }
            if mark.mark == "question" {
                row.open_question = true;
            }
        }
        let rank = display_rank(mark, state);
        let replace = best
            .get(&row_index)
            .map(|(have, _, _)| rank < *have)
            .unwrap_or(true);
        if replace && !mark.agent {
            best.insert(row_index, (rank, mark_index, state.to_string()));
        }
    }
    for (row_index, (_, mark_index, state)) in best {
        let mark = &marks[mark_index];
        let row = &mut inbox.rows[row_index];
        row.mark = mark.mark.clone();
        row.mark_author = mark.author.clone();
        row.mark_state = state;
        row.mark_note = mark.note.clone();
        row.mark_id = mark.id.clone();
    }
    finish(inbox);
}

fn display_rank(mark: &Mark, state: &str) -> u8 {
    let base = match mark.mark.as_str() {
        "suspect" => 0,
        "question" => 1,
        "verified" => 2,
        "note" => 3,
        _ => 4,
    };
    if state == "stale" {
        base
    } else {
        base.saturating_add(10)
    }
}
