use tree_sitter::{Language, Node};

use super::Grammar;
use crate::highlight::editing::{EditingKinds, c_folds};
use crate::highlight::{
    c_decls, c_locals, c_members, c_outline, c_types, context, imports, includes, site,
};

const HIGHLIGHTS: &str = concat!(
    include_str!("../../../queries/c/highlights.scm"),
    "\n",
    include_str!("../../../queries/cpp/highlights.scm")
);

pub const KEYWORDS: &[&str] = &[
    "alignas",
    "alignof",
    "and",
    "and_eq",
    "asm",
    "auto",
    "bitand",
    "bitor",
    "bool",
    "break",
    "case",
    "catch",
    "char",
    "char8_t",
    "char16_t",
    "char32_t",
    "class",
    "compl",
    "concept",
    "const",
    "const_cast",
    "consteval",
    "constexpr",
    "constinit",
    "continue",
    "co_await",
    "co_return",
    "co_yield",
    "decltype",
    "default",
    "define",
    "delete",
    "do",
    "double",
    "dynamic_cast",
    "elif",
    "else",
    "endif",
    "enum",
    "error",
    "explicit",
    "export",
    "extern",
    "false",
    "final",
    "float",
    "for",
    "friend",
    "goto",
    "if",
    "ifdef",
    "ifndef",
    "import",
    "include",
    "inline",
    "int",
    "long",
    "module",
    "mutable",
    "namespace",
    "new",
    "noexcept",
    "not",
    "not_eq",
    "nullptr",
    "operator",
    "or",
    "or_eq",
    "override",
    "pragma",
    "private",
    "protected",
    "public",
    "register",
    "reinterpret_cast",
    "requires",
    "return",
    "short",
    "signed",
    "sizeof",
    "static",
    "static_assert",
    "static_cast",
    "struct",
    "switch",
    "template",
    "this",
    "thread_local",
    "throw",
    "true",
    "try",
    "typedef",
    "typeid",
    "typename",
    "undef",
    "union",
    "unsigned",
    "using",
    "virtual",
    "void",
    "volatile",
    "wchar_t",
    "while",
    "xor",
    "xor_eq",
];

const SYMBOL_KINDS: &[&str] = &[
    "identifier",
    "type_identifier",
    "field_identifier",
    "primitive_type",
    "statement_identifier",
    "namespace_identifier",
];

pub fn grammar() -> Grammar {
    Grammar {
        language: Language::new(tree_sitter_cpp::LANGUAGE),
        highlights: HIGHLIGHTS,
        keywords: KEYWORDS,
        local_kinds: super::c::LOCAL_KINDS,
        declares: c_decls::declares_local,
        local_detail: c_locals::detail,
        symbol_kinds: SYMBOL_KINDS,
        qualifier,
        outline: c_outline::outline,
        member_ops: super::c::MEMBER_OPS,
        member_kinds: super::c::MEMBER_KINDS,
        receiver: c_members::receiver_chain,
        type_table: c_types::build,
        includes: includes::c_includes,
        site: site::cpp_site,
        context: context::c_context,
        imports: imports::no_imports,
        editing: EditingKinds {
            strings: &["string_literal", "char_literal", "raw_string_literal"],
            comments: &["comment"],
            bodies: super::c::BODIES,
            folds: c_folds,
        },
    }
}

fn qualifier(node: Node<'_>, text: &str) -> Option<String> {
    let mut top = node;
    while let Some(parent) = top.parent() {
        if parent.kind() != "qualified_identifier" {
            break;
        }
        let is_name = parent
            .child_by_field_name("name")
            .is_some_and(|n| n.id() == top.id());
        if !is_name {
            break;
        }
        top = parent;
    }
    if top.id() == node.id() {
        return None;
    }
    text.get(top.start_byte()..node.start_byte())
        .map(|q| q.trim_end_matches("::").to_string())
        .filter(|q| !q.is_empty())
}
