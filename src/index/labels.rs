use crate::extract::{Scope, Visibility};
use crate::ffi::ItemKind;

pub fn scope_rank(scope: Scope) -> u64 {
    match scope {
        Scope::Workspace => 0,
        Scope::Sysroot => 1,
        Scope::DirectDep => 2,
        Scope::Transitive => 3,
        Scope::Cache => 4,
    }
}

const KIND_ORDER: [ItemKind; 22] = [
    ItemKind::Keyword,
    ItemKind::Local,
    ItemKind::Crate,
    ItemKind::Mod,
    ItemKind::Struct,
    ItemKind::Enum,
    ItemKind::Union,
    ItemKind::Trait,
    ItemKind::Fn,
    ItemKind::Method,
    ItemKind::Macro,
    ItemKind::Const,
    ItemKind::Type,
    ItemKind::Static,
    ItemKind::Heading,
    ItemKind::Class,
    ItemKind::Namespace,
    ItemKind::Field,
    ItemKind::Table,
    ItemKind::Target,
    ItemKind::Variant,
    ItemKind::Header,
];

pub fn kind_rank(kind: ItemKind) -> u64 {
    KIND_ORDER.iter().position(|k| *k == kind).unwrap_or(0) as u64
}

pub fn kind_from_rank(rank: u64) -> ItemKind {
    KIND_ORDER
        .get(rank as usize)
        .copied()
        .unwrap_or(ItemKind::Type)
}

pub fn item_kind_from_label(label: &str) -> ItemKind {
    match label {
        "keyword" => ItemKind::Keyword,
        "local" => ItemKind::Local,
        "crate" => ItemKind::Crate,
        "mod" => ItemKind::Mod,
        "struct" => ItemKind::Struct,
        "enum" => ItemKind::Enum,
        "union" => ItemKind::Union,
        "trait" => ItemKind::Trait,
        "fn" => ItemKind::Fn,
        "method" => ItemKind::Method,
        "macro" => ItemKind::Macro,
        "const" => ItemKind::Const,
        "static" => ItemKind::Static,
        "heading" => ItemKind::Heading,
        "class" => ItemKind::Class,
        "namespace" => ItemKind::Namespace,
        "field" => ItemKind::Field,
        "table" => ItemKind::Table,
        "target" => ItemKind::Target,
        "variant" => ItemKind::Variant,
        "header" => ItemKind::Header,
        _ => ItemKind::Type,
    }
}

pub fn item_kind_label(kind: ItemKind) -> &'static str {
    match kind {
        ItemKind::Keyword => "keyword",
        ItemKind::Local => "local",
        ItemKind::Crate => "crate",
        ItemKind::Mod => "mod",
        ItemKind::Struct => "struct",
        ItemKind::Enum => "enum",
        ItemKind::Union => "union",
        ItemKind::Trait => "trait",
        ItemKind::Fn => "fn",
        ItemKind::Method => "method",
        ItemKind::Macro => "macro",
        ItemKind::Const => "const",
        ItemKind::Type => "type",
        ItemKind::Static => "static",
        ItemKind::Heading => "heading",
        ItemKind::Class => "class",
        ItemKind::Namespace => "namespace",
        ItemKind::Field => "field",
        ItemKind::Table => "table",
        ItemKind::Target => "target",
        ItemKind::Variant => "variant",
        ItemKind::Header => "header",
    }
}

pub fn visibility_label(vis: Visibility) -> &'static str {
    match vis {
        Visibility::Pub => "pub",
        Visibility::Crate => "crate",
        Visibility::Private => "private",
    }
}

pub fn scope_label(scope: Scope) -> &'static str {
    match scope {
        Scope::Workspace => "workspace",
        Scope::Sysroot => "sysroot",
        Scope::DirectDep => "direct_dep",
        Scope::Transitive => "transitive",
        Scope::Cache => "cache",
    }
}

pub fn name_hash(name: &str) -> u64 {
    name.bytes().fold(0xcbf2_9ce4_8422_2325u64, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    })
}
