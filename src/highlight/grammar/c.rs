use tree_sitter::{Language, Node};

use super::Grammar;
use crate::highlight::{c_locals, c_members, c_outline, c_types, imports, includes, site};

pub const HIGHLIGHTS: &str = include_str!("../../../queries/c/highlights.scm");

pub const KEYWORDS: &[&str] = &[
    "alignas",
    "alignof",
    "auto",
    "bool",
    "break",
    "case",
    "char",
    "const",
    "constexpr",
    "continue",
    "default",
    "define",
    "do",
    "double",
    "elif",
    "else",
    "endif",
    "enum",
    "error",
    "extern",
    "false",
    "float",
    "for",
    "goto",
    "if",
    "ifdef",
    "ifndef",
    "include",
    "inline",
    "int",
    "long",
    "nullptr",
    "pragma",
    "register",
    "restrict",
    "return",
    "short",
    "signed",
    "sizeof",
    "static",
    "static_assert",
    "struct",
    "switch",
    "thread_local",
    "true",
    "typedef",
    "typeof",
    "undef",
    "union",
    "unsigned",
    "void",
    "volatile",
    "while",
    "_Atomic",
    "_Generic",
    "_Noreturn",
];

pub const LOCAL_KINDS: &[&str] = &["identifier", "type_identifier", "field_identifier"];
pub const MEMBER_OPS: &[&str] = &["->", "."];
pub const MEMBER_KINDS: &[&str] = &["field_identifier"];

pub const SYMBOL_KINDS: &[&str] = &[
    "identifier",
    "type_identifier",
    "field_identifier",
    "primitive_type",
    "statement_identifier",
];

pub fn grammar() -> Grammar {
    Grammar {
        language: Language::new(tree_sitter_c::LANGUAGE),
        highlights: HIGHLIGHTS,
        keywords: KEYWORDS,
        local_kinds: LOCAL_KINDS,
        declares: c_locals::declares_local,
        local_detail: c_locals::detail,
        symbol_kinds: SYMBOL_KINDS,
        qualifier: no_qualifier,
        outline: c_outline::outline,
        member_ops: MEMBER_OPS,
        member_kinds: MEMBER_KINDS,
        receiver_type: c_members::receiver_type,
        type_table: c_types::build,
        includes: includes::c_includes,
        site: site::c_site,
        imports: imports::no_imports,
    }
}

fn no_qualifier(_: Node<'_>, _: &str) -> Option<String> {
    None
}
