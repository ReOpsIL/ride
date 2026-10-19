use crate::ffi::{CompletionContext, CompletionHit, ItemKind};

pub fn apply(hits: &mut Vec<CompletionHit>, name: &str, context: CompletionContext) {
    keep(hits, |h| h.name == name);
    if let Some(pred) = kinds(context) {
        keep(hits, |h| pred(h.item_kind));
    }
    if context == CompletionContext::TypePosition {
        keep(hits, |h| is_nominal(h.item_kind));
    }
}

fn keep(hits: &mut Vec<CompletionHit>, pred: impl Fn(&CompletionHit) -> bool) {
    if hits.iter().any(&pred) {
        hits.retain(pred);
    }
}

fn kinds(context: CompletionContext) -> Option<fn(ItemKind) -> bool> {
    match context {
        CompletionContext::TypePosition => Some(is_type),
        CompletionContext::ValuePosition => Some(is_value),
        CompletionContext::Unknown | CompletionContext::MemberAccess => None,
    }
}

fn is_nominal(kind: ItemKind) -> bool {
    matches!(
        kind,
        ItemKind::Struct | ItemKind::Enum | ItemKind::Trait | ItemKind::Union | ItemKind::Class
    )
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
        apply(&mut hits, "Path", CompletionContext::TypePosition);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].name, "Path");
        assert_eq!(hits[0].item_kind, ItemKind::Struct);
    }

    #[test]
    fn a_value_position_keeps_the_function() {
        let mut hits = vec![hit("path", ItemKind::Fn), hit("Path", ItemKind::Struct)];
        apply(&mut hits, "path", CompletionContext::ValuePosition);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].name, "path");
        assert_eq!(hits[0].item_kind, ItemKind::Fn);
    }

    #[test]
    fn a_nominal_type_wins_over_an_alias_of_the_same_name() {
        let mut hits = vec![hit("Result", ItemKind::Type), hit("Result", ItemKind::Enum)];
        apply(&mut hits, "Result", CompletionContext::TypePosition);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].item_kind, ItemKind::Enum);
    }

    #[test]
    fn an_alias_stays_when_it_is_the_only_type() {
        let mut hits = vec![hit("Result", ItemKind::Type)];
        apply(&mut hits, "Result", CompletionContext::TypePosition);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].item_kind, ItemKind::Type);
    }

    #[test]
    fn an_only_case_mismatch_stays_when_nothing_matches() {
        let mut hits = vec![hit("path", ItemKind::Fn)];
        apply(&mut hits, "Path", CompletionContext::TypePosition);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].name, "path");
    }
}
