use std::collections::HashMap;

use super::model::{Change, Group, Row};

pub fn prove(rows: &mut Vec<Row>, shapes: &[String]) {
    let mut added: HashMap<String, Vec<usize>> = HashMap::new();
    let mut removed: HashMap<String, Vec<usize>> = HashMap::new();
    for (index, row) in rows.iter().enumerate() {
        if row.shape.is_empty() {
            continue;
        }
        match row.change {
            Change::Added => added.entry(row.shape.clone()).or_default().push(index),
            Change::Removed => removed.entry(row.shape.clone()).or_default().push(index),
            _ => {}
        }
    }
    let mut drop_at = Vec::new();
    let mut made = Vec::new();
    for (shape, added_at) in &added {
        let Some(removed_at) = removed.get(shape) else {
            continue;
        };
        if added_at.len() != 1 || removed_at.len() != 1 {
            continue;
        }
        if shapes.iter().filter(|seen| *seen == shape).count() != 2 {
            continue;
        }
        let new = &rows[added_at[0]];
        let old = &rows[removed_at[0]];
        let mut row = new.clone();
        row.change = Change::Moved;
        row.group = Group::Equivalent;
        row.old_path = old.path.clone();
        row.detail = format!("moved from {}", old.path);
        row.checks.clear();
        made.push(row);
        drop_at.push(added_at[0]);
        drop_at.push(removed_at[0]);
    }
    drop_at.sort_unstable();
    drop_at.dedup();
    for index in drop_at.into_iter().rev() {
        rows.remove(index);
    }
    rows.extend(made);
}
