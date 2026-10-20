use crate::ffi::{CompletionContext, CompletionHit, ItemKind};
use crate::highlight::SymbolRole;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Position {
    Type,
    Qualifier,
    Value,
    Any,
}

impl Position {
    pub fn of(role: SymbolRole, site: CompletionContext) -> Self {
        match (role, site) {
            (SymbolRole::Primitive | SymbolRole::Type, _) => Self::Type,
            (SymbolRole::Qualifier, _) => Self::Qualifier,
            (SymbolRole::Other, CompletionContext::TypePosition) => Self::Type,
            (SymbolRole::Other, CompletionContext::ValuePosition) => Self::Value,
            (SymbolRole::Other, _) => Self::Any,
        }
    }
}

pub fn apply(hits: &mut Vec<CompletionHit>, name: &str, position: Position) {
    keep(hits, |h| h.name == name);
    if let Some(pred) = kinds(position) {
        keep(hits, |h| pred(h.item_kind));
    }
}

fn keep(hits: &mut Vec<CompletionHit>, pred: impl Fn(&CompletionHit) -> bool) {
    if hits.iter().any(&pred) {
        hits.retain(pred);
    }
}

fn kinds(position: Position) -> Option<fn(ItemKind) -> bool> {
    match position {
        Position::Type => Some(is_type),
        Position::Qualifier => Some(is_scope),
        Position::Value => Some(is_value),
        Position::Any => None,
    }
}

fn is_type(kind: ItemKind) -> bool {
    matches!(
        kind,
        ItemKind::Struct
            | ItemKind::Enum
            | ItemKind::Trait
            | ItemKind::Union
            | ItemKind::Type
            | ItemKind::Class
    )
}

fn is_scope(kind: ItemKind) -> bool {
    is_type(kind) || matches!(kind, ItemKind::Mod | ItemKind::Namespace)
}

fn is_value(kind: ItemKind) -> bool {
    matches!(
        kind,
        ItemKind::Fn
            | ItemKind::Method
            | ItemKind::Const
            | ItemKind::Static
            | ItemKind::Macro
            | ItemKind::Local
            | ItemKind::Variant
            | ItemKind::Field
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hit(name: &str, kind: ItemKind) -> CompletionHit {
        CompletionHit::local(name, kind, 1.0, None)
    }

    #[test]
    fn a_type_position_keeps_the_type_and_its_case() {
        let mut hits = vec![hit("path", ItemKind::Fn), hit("Path", ItemKind::Struct)];
        apply(&mut hits, "Path", Position::Type);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].name, "Path");
        assert_eq!(hits[0].item_kind, ItemKind::Struct);
    }

    #[test]
    fn a_value_position_keeps_the_function() {
        let mut hits = vec![hit("path", ItemKind::Fn), hit("Path", ItemKind::Struct)];
        apply(&mut hits, "path", Position::Value);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].name, "path");
        assert_eq!(hits[0].item_kind, ItemKind::Fn);
    }

    #[test]
    fn a_type_position_keeps_aliases_beside_nominal_types() {
        let mut hits = vec![hit("Result", ItemKind::Type), hit("Result", ItemKind::Enum)];
        apply(&mut hits, "Result", Position::Type);
        assert_eq!(hits.len(), 2);
    }

    #[test]
    fn a_qualifier_keeps_the_type_over_a_same_named_variant() {
        let mut hits = vec![
            hit("String", ItemKind::Variant),
            hit("String", ItemKind::Struct),
        ];
        apply(&mut hits, "String", Position::Qualifier);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].item_kind, ItemKind::Struct);
    }

    #[test]
    fn a_qualifier_keeps_a_module() {
        let mut hits = vec![hit("io", ItemKind::Fn), hit("io", ItemKind::Mod)];
        apply(&mut hits, "io", Position::Qualifier);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].item_kind, ItemKind::Mod);
    }

    #[test]
    fn an_only_case_mismatch_stays_when_nothing_matches() {
        let mut hits = vec![hit("path", ItemKind::Fn)];
        apply(&mut hits, "Path", Position::Type);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].name, "path");
    }
}
