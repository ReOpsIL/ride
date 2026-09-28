use crate::ffi::{CompletionHit, ItemKind};

use super::dialect::Dialect;
use super::parse::Parsed;

#[derive(PartialEq, Eq, PartialOrd, Ord)]
enum Owner {
    Field,
    Inherent,
    Trait,
}

pub fn members(items: Vec<Parsed>, dialect: Dialect) -> Vec<CompletionHit> {
    let mut ranked: Vec<(Owner, String, CompletionHit)> = items
        .into_iter()
        .filter(|p| {
            matches!(
                p.hit.item_kind,
                ItemKind::Method | ItemKind::Fn | ItemKind::Field
            )
        })
        .map(|p| (owner(&p), p.sort_text, p.hit))
        .collect();
    match dialect {
        Dialect::Rust => ranked.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.2.name.cmp(&b.2.name))),
        Dialect::Clang => {
            ranked.sort_by(|a, b| a.1.cmp(&b.1).then_with(|| a.2.name.cmp(&b.2.name)))
        }
    }
    ranked.into_iter().map(|(_, _, hit)| hit).collect()
}

fn owner(parsed: &Parsed) -> Owner {
    match (parsed.hit.item_kind, parsed.from_trait) {
        (ItemKind::Field, _) => Owner::Field,
        (_, true) => Owner::Trait,
        _ => Owner::Inherent,
    }
}
