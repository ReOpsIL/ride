use crate::ffi::{CompletionHit, ItemKind, SymbolAt};
use crate::highlight::{Member, TypeTable};

pub fn definitions(tables: &[&TypeTable], symbol: &SymbolAt, score: f32) -> Vec<CompletionHit> {
    let own = tables
        .first()
        .and_then(|t| t.declared_at(symbol.start_byte));
    let mut found = candidates(tables, symbol);
    if let Some(own) = own
        && !found.iter().any(|m| same(m, &own))
    {
        found.push(own);
    }
    found
        .into_iter()
        .filter(|m| m.item.kind == ItemKind::Variant && m.item.name == symbol.name)
        .map(|m| {
            let origin = m.origin.map(|o| o.display().to_string());
            CompletionHit::from_outline(&m.item, score, origin)
        })
        .collect()
}

fn same(a: &Member, b: &Member) -> bool {
    a.origin == b.origin && a.item.name_start_byte == b.item.name_start_byte
}

fn candidates(tables: &[&TypeTable], symbol: &SymbolAt) -> Vec<Member> {
    match symbol.qualifier.as_deref() {
        Some(qualifier) => {
            let segments: Vec<String> = qualifier.split("::").map(str::to_string).collect();
            TypeTable::scoped(tables, &segments)
        }
        None => TypeTable::unqualified(tables, &symbol.name, symbol.start_byte),
    }
}
