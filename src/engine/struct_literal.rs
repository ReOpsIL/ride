use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, ItemKind};

use super::snapshot::Snapshot;
use super::{merge, rust_members};

pub fn hits(snap: &Snapshot, q: &CompletionQuery, type_name: &str) -> Option<CompletionResponse> {
    let literal = snap.literal.as_ref()?;
    let mut pool: Vec<CompletionHit> = rust_members::buffer_members(snap, type_name, &q.prefix)
        .into_iter()
        .filter(|h| h.item_kind == ItemKind::Field && !literal.written.contains(&h.name))
        .collect();
    if pool.is_empty() {
        return None;
    }
    if !literal.colon_follows {
        for hit in &mut pool {
            hit.insert_text = format!("{}: ", hit.name);
        }
    }
    merge::keep_order(&mut pool, &q.prefix);
    Some(merge::finish(q, pool, false))
}
