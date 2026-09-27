use std::collections::HashSet;

use crate::ffi::{CompletionHit, OutlineItem, SymbolAt};
use crate::highlight::TypeTable;

pub fn hits(
    outline: &[OutlineItem],
    types: &TypeTable,
    symbol: &SymbolAt,
    score: f32,
) -> Vec<CompletionHit> {
    let owned = owned_by_qualifier(types, symbol);
    let mut named: Vec<&OutlineItem> = outline.iter().filter(|o| o.name == symbol.name).collect();
    named.sort_by_key(|o| !owned.contains(&o.name_start_byte));
    named
        .into_iter()
        .map(|o| CompletionHit::from_outline(o, score, None))
        .collect()
}

fn owned_by_qualifier(types: &TypeTable, symbol: &SymbolAt) -> HashSet<u32> {
    let Some(qualifier) = symbol.qualifier.as_deref() else {
        return HashSet::new();
    };
    let segments: Vec<String> = qualifier.split("::").map(str::to_string).collect();
    TypeTable::scoped(&[types], &segments)
        .into_iter()
        .filter(|m| m.item.name == symbol.name)
        .map(|m| m.item.name_start_byte)
        .collect()
}
