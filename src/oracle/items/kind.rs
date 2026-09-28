use crate::ffi::ItemKind;

use super::dialect::Dialect;

pub fn item_kind(lsp_kind: u64, is_macro: bool, dialect: Dialect) -> Option<ItemKind> {
    let kind = match (lsp_kind, dialect) {
        (2, _) => ItemKind::Method,
        (3 | 4, Dialect::Rust) if is_macro => ItemKind::Macro,
        (3 | 4, _) => ItemKind::Fn,
        (5 | 10, _) => ItemKind::Field,
        (6, _) => ItemKind::Local,
        (7 | 8, Dialect::Clang) => ItemKind::Class,
        (9, Dialect::Clang) => ItemKind::Namespace,
        (1 | 12, Dialect::Clang) => ItemKind::Const,
        (18, Dialect::Clang) => ItemKind::Type,
        (7 | 22, _) => ItemKind::Struct,
        (8, _) => ItemKind::Trait,
        (9, _) => ItemKind::Mod,
        (12, _) => ItemKind::Static,
        (13, _) => ItemKind::Enum,
        (20, _) => ItemKind::Variant,
        (21, _) => ItemKind::Const,
        (11 | 25, _) => ItemKind::Type,
        _ => return None,
    };
    Some(kind)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keywords_snippets_and_attributes_are_dropped_for_rust() {
        for lsp in [1, 14, 15, 18] {
            assert_eq!(item_kind(lsp, false, Dialect::Rust), None);
        }
    }

    #[test]
    fn a_function_labelled_as_a_macro_is_a_macro_in_rust_only() {
        assert_eq!(item_kind(3, true, Dialect::Rust), Some(ItemKind::Macro));
        assert_eq!(item_kind(3, true, Dialect::Clang), Some(ItemKind::Fn));
    }

    #[test]
    fn clangd_classes_namespaces_and_macros_map_to_c_kinds() {
        assert_eq!(item_kind(7, false, Dialect::Clang), Some(ItemKind::Class));
        assert_eq!(
            item_kind(9, false, Dialect::Clang),
            Some(ItemKind::Namespace)
        );
        assert_eq!(item_kind(1, false, Dialect::Clang), Some(ItemKind::Const));
        assert_eq!(item_kind(14, false, Dialect::Clang), None);
    }
}
