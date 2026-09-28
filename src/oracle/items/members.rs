use crate::ffi::{CompletionHit, ItemKind};

use super::parse::Parsed;

#[derive(PartialEq, Eq, PartialOrd, Ord)]
enum Owner {
    Field,
    Inherent,
    Trait,
}

pub fn members(items: Vec<Parsed>) -> Vec<CompletionHit> {
    let mut ranked: Vec<(Owner, CompletionHit)> = items
        .into_iter()
        .filter(|p| {
            matches!(
                p.hit.item_kind,
                ItemKind::Method | ItemKind::Fn | ItemKind::Field
            )
        })
        .map(|p| (owner(&p), p.hit))
        .collect();
    ranked.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.name.cmp(&b.1.name)));
    ranked.into_iter().map(|(_, hit)| hit).collect()
}

fn owner(parsed: &Parsed) -> Owner {
    match (parsed.hit.item_kind, parsed.from_trait) {
        (ItemKind::Field, _) => Owner::Field,
        (_, true) => Owner::Trait,
        _ => Owner::Inherent,
    }
}
