use crate::ffi::ItemKind;

pub const EXACT: f32 = 1000.0;
pub const KEYWORD: f32 = 500.0;
pub const TIER_DECLARED: f32 = 900.0;
pub const TIER_ITEM: f32 = 850.0;
pub const TIER_HEADER: f32 = 800.0;
pub const TIER_MENTION: f32 = 700.0;
pub const IMPORT_BONUS: f32 = 600.0;
pub const PRELUDE_BONUS: f32 = 300.0;
pub const CASE_BONUS: f32 = 50.0;
pub const DEPRECATED_PENALTY: f32 = 200.0;
const LEN_CAP: u64 = 40;

pub fn length_bonus(len: u64) -> f32 {
    LEN_CAP.saturating_sub(len) as f32
}

pub fn exact_bonus(name: &str, prefix: &str) -> f32 {
    if !prefix.is_empty() && name.eq_ignore_ascii_case(prefix) {
        EXACT
    } else {
        0.0
    }
}

pub fn case_bonus(name: &str, prefix: &str) -> f32 {
    match (name.chars().next(), prefix.chars().next()) {
        (Some(n), Some(p)) if n.is_uppercase() == p.is_uppercase() => CASE_BONUS,
        _ => 0.0,
    }
}

pub fn kind_weight(kind: ItemKind) -> f32 {
    match kind {
        ItemKind::Struct
        | ItemKind::Enum
        | ItemKind::Trait
        | ItemKind::Union
        | ItemKind::Type
        | ItemKind::Class => 40.0,
        ItemKind::Fn | ItemKind::Macro | ItemKind::Target => 35.0,
        ItemKind::Mod | ItemKind::Crate | ItemKind::Namespace | ItemKind::Table => 30.0,
        ItemKind::Method | ItemKind::Variant => 20.0,
        ItemKind::Const | ItemKind::Static => 10.0,
        ItemKind::Keyword
        | ItemKind::Local
        | ItemKind::Heading
        | ItemKind::Field
        | ItemKind::Header => 0.0,
    }
}

pub fn tiered(tier: f32, name: &str, kind: ItemKind, prefix: &str) -> f32 {
    tier + exact_bonus(name, prefix)
        + kind_weight(kind)
        + length_bonus(name.chars().count() as u64)
        + case_bonus(name, prefix)
}
