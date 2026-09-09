use crate::ffi::ItemKind;
use crate::index::item_kind_label;

pub fn parse_prefix(raw: &str, existing: Option<ItemKind>) -> (Option<ItemKind>, String) {
    if existing.is_some() {
        return (existing, raw.trim().to_string());
    }
    let Some((head, rest)) = raw.split_once(':') else {
        return (None, raw.trim().to_string());
    };
    let kind = match head {
        "fn" => Some(ItemKind::Fn),
        "struct" => Some(ItemKind::Struct),
        "enum" => Some(ItemKind::Enum),
        "union" => Some(ItemKind::Union),
        "trait" => Some(ItemKind::Trait),
        "mod" => Some(ItemKind::Mod),
        "macro" => Some(ItemKind::Macro),
        "const" => Some(ItemKind::Const),
        "type" => Some(ItemKind::Type),
        "static" => Some(ItemKind::Static),
        "method" => Some(ItemKind::Method),
        "crate" => Some(ItemKind::Crate),
        _ => None,
    };
    if kind.is_some() {
        (kind, rest.trim().to_string())
    } else {
        (None, raw.trim().to_string())
    }
}

pub fn kind_term(kind: ItemKind) -> &'static str {
    item_kind_label(kind)
}

pub fn escape_regex(s: &str) -> String {
    let mut out = String::new();
    for c in s.chars() {
        if matches!(
            c,
            '.' | '+' | '*' | '?' | '(' | ')' | '[' | ']' | '{' | '}' | '^' | '$' | '|' | '\\'
        ) {
            out.push('\\');
        }
        out.push(c);
    }
    out
}
