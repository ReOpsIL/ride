use std::collections::HashSet;

use crate::ffi::{CompletionHit, OutlineItem, SymbolAt};
use crate::highlight::TypeTable;

const PATH_ROOTS: &[&str] = &["self", "Self", "crate", "super"];

pub fn hits(
    outline: &[OutlineItem],
    types: &TypeTable,
    symbol: &SymbolAt,
    score: f32,
) -> Vec<CompletionHit> {
    let owned = owned_by_qualifier(types, symbol);
    let reaches_here = symbol
        .qualifier
        .as_deref()
        .is_none_or(|q| starts_here(q, outline));
    let mut named: Vec<&OutlineItem> = outline
        .iter()
        .filter(|o| o.name == symbol.name)
        .filter(|o| reaches_here || owned.contains(&o.name_start_byte))
        .collect();
    named.sort_by_key(|o| !owned.contains(&o.name_start_byte));
    named
        .into_iter()
        .map(|o| CompletionHit::from_outline(o, score, None))
        .collect()
}

fn starts_here(qualifier: &str, outline: &[OutlineItem]) -> bool {
    let head = qualifier.split("::").next().unwrap_or(qualifier);
    PATH_ROOTS.contains(&head) || outline.iter().any(|o| o.name == head)
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::highlight::BufferSession;

    fn names_at(src: &str, needle: &str) -> Vec<u32> {
        let (session, _) =
            BufferSession::open_lang(crate::highlight::Lang::Rust, src.to_string(), None)
                .expect("session");
        let at = src.find(needle).expect("needle") as u32 + needle.len() as u32 - 1;
        let symbol = session.symbol_at(at).expect("symbol");
        let types = session.scope().types.clone();
        hits(session.outline(), &types, &symbol, 1.0)
            .iter()
            .filter_map(|h| h.name_byte)
            .collect()
    }

    #[test]
    fn a_foreign_path_does_not_reach_a_local_item() {
        let src = "type Result<T> = std::result::Result<T, ()>;\n";
        assert!(names_at(src, "result::Result").is_empty());
    }

    #[test]
    fn a_local_module_path_reaches_its_item() {
        let src = "mod a {\n    pub fn f() {}\n}\nfn g() {\n    a::f();\n}\n";
        let decl = src.find("fn f").expect("decl") as u32 + 3;
        assert_eq!(names_at(src, "a::f"), [decl]);
    }

    #[test]
    fn a_crate_path_reaches_a_local_item() {
        let src = "struct Thing;\nfn g(_: crate::Thing) {}\n";
        assert_eq!(names_at(src, "crate::Thing"), [7]);
    }
}
