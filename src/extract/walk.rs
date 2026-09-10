use std::path::{Path, PathBuf};

use tree_sitter::Node;

use crate::ffi::ItemKind;

use super::attrs::is_test_only;
use super::docs::inner_docs;
use super::emit::{EmitArgs, emit_fn, emit_macro, emit_named};
use super::item::{CrateContext, ItemDoc, Visibility, field_text};
use super::mod_walk::walk_mod;
use super::reach::Assoc;
use super::reexport::Reexport;
use super::types_walk::{walk_impl, walk_trait};
use super::use_walk::collect_use;
use super::variants::emit_variants;

pub struct PendingMod {
    pub file: PathBuf,
    pub module_path: Vec<String>,
    pub reach: bool,
}

pub struct FileExtract {
    pub items: Vec<ItemDoc>,
    pub pending: Vec<PendingMod>,
    pub excluded: Vec<PathBuf>,
    pub reexports: Vec<Reexport>,
    pub crate_aliases: Vec<(String, String)>,
    pub assoc: Vec<Assoc>,
    pub inner_docs: String,
}

pub struct TypeCtx {
    pub type_path: String,
    pub trait_path: Option<String>,
    pub default_vis: Option<Visibility>,
}

pub fn extract_tree(
    root: Node<'_>,
    source: &str,
    file: &Path,
    module_path: &[String],
    reach: bool,
    ctx: &CrateContext,
) -> FileExtract {
    let mut out = FileExtract {
        items: Vec::new(),
        pending: Vec::new(),
        excluded: Vec::new(),
        reexports: Vec::new(),
        crate_aliases: Vec::new(),
        assoc: Vec::new(),
        inner_docs: inner_docs(root, source),
    };
    {
        let mut args = EmitArgs {
            source,
            file,
            module_path,
            reach,
            ctx,
            out: &mut out,
        };
        walk_list(root, &mut args, None);
    }
    out
}

pub fn walk_list(node: Node<'_>, args: &mut EmitArgs<'_>, type_ctx: Option<&TypeCtx>) {
    super::ts::each_named(node, |child| {
        walk_item(child, args, type_ctx);
    });
}

fn walk_item(node: Node<'_>, args: &mut EmitArgs<'_>, type_ctx: Option<&TypeCtx>) {
    let hidden = is_test_only(node, args.source);
    if node.kind() == "mod_item" {
        return walk_mod(node, args, hidden);
    }
    if hidden {
        return;
    }
    match node.kind() {
        "function_item" | "function_signature_item" => emit_fn(node, args, type_ctx),
        "struct_item" => emit_named(node, args, ItemKind::Struct, type_ctx),
        "enum_item" => {
            emit_named(node, args, ItemKind::Enum, type_ctx);
            emit_variants(node, args);
        }
        "union_item" => emit_named(node, args, ItemKind::Union, type_ctx),
        "const_item" => emit_named(node, args, ItemKind::Const, type_ctx),
        "static_item" => emit_named(node, args, ItemKind::Static, type_ctx),
        "type_item" | "associated_type" => emit_named(node, args, ItemKind::Type, type_ctx),
        "trait_item" => walk_trait(node, args),
        "impl_item" => walk_impl(node, args),
        "macro_definition" => emit_macro(node, args),
        "use_declaration" => collect_use(
            node,
            args.source,
            args.file,
            args.module_path,
            args.reach,
            &mut args.out.reexports,
        ),
        "extern_crate_declaration" => {
            if let Some(name) = field_text(node, "name", args.source)
                && let Some(alias) = field_text(node, "alias", args.source)
            {
                args.out.crate_aliases.push((alias, name));
            }
        }
        "foreign_mod_item" => {
            if let Some(body) = node.child_by_field_name("body") {
                walk_list(body, args, None);
            }
        }
        _ => {}
    }
}
