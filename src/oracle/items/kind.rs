use crate::ffi::ItemKind;

pub fn item_kind(lsp_kind: u64, is_macro: bool) -> Option<ItemKind> {
    let kind = match lsp_kind {
        2 => ItemKind::Method,
        3 | 4 if is_macro => ItemKind::Macro,
        3 | 4 => ItemKind::Fn,
        5 | 10 => ItemKind::Field,
        6 => ItemKind::Local,
        7 | 22 => ItemKind::Struct,
        8 => ItemKind::Trait,
        9 => ItemKind::Mod,
        12 => ItemKind::Static,
        13 => ItemKind::Enum,
        20 => ItemKind::Variant,
        21 => ItemKind::Const,
        11 | 25 => ItemKind::Type,
        _ => return None,
    };
    Some(kind)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keywords_snippets_and_attributes_are_dropped() {
        for lsp in [14, 15, 18] {
            assert_eq!(item_kind(lsp, false), None);
        }
    }

    #[test]
    fn a_function_labelled_as_a_macro_is_a_macro() {
        assert_eq!(item_kind(3, true), Some(ItemKind::Macro));
        assert_eq!(item_kind(3, false), Some(ItemKind::Fn));
    }
}
