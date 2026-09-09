use std::path::{Path, PathBuf};

use tree_sitter::Node;

use crate::ffi::ItemKind;

use super::docs::inner_docs;
use super::emit::{EmitArgs, emit_fn, emit_macro, emit_named};
use super::impls::type_as_written;
use super::item::{CrateContext, ItemDoc, Visibility, field_text};
use super::mods::resolve_mod_file;
use super::reexport::Reexport;
use super::use_walk::collect_use;
use super::vis::{path_attribute, visibility};

pub struct PendingMod {
    pub file: PathBuf,
    pub module_path: Vec<String>,
}

pub struct FileExtract {
    pub items: Vec<ItemDoc>,
    pub pending: Vec<PendingMod>,
    pub reexports: Vec<Reexport>,
    pub crate_aliases: Vec<(String, String)>,
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
    ctx: &CrateContext,
) -> FileExtract {
    let mut out = FileExtract {
        items: Vec::new(),
        pending: Vec::new(),
        reexports: Vec::new(),
        crate_aliases: Vec::new(),
        inner_docs: inner_docs(root, source),
    };
    {
        let mut args = EmitArgs {
            source,
            file,
            module_path,
            ctx,
            out: &mut out,
        };
        walk_list(root, &mut args, None);
    }
    out
}

fn walk_list(node: Node<'_>, args: &mut EmitArgs<'_>, type_ctx: Option<&TypeCtx>) {
    super::ts::each_named(node, |child| {
        walk_item(child, args, type_ctx);
    });
}

fn walk_item(node: Node<'_>, args: &mut EmitArgs<'_>, type_ctx: Option<&TypeCtx>) {
    match node.kind() {
        "function_item" | "function_signature_item" => emit_fn(node, args, type_ctx),
        "struct_item" => emit_named(node, args, ItemKind::Struct, type_ctx),
        "enum_item" => emit_named(node, args, ItemKind::Enum, type_ctx),
        "union_item" => emit_named(node, args, ItemKind::Union, type_ctx),
        "const_item" => emit_named(node, args, ItemKind::Const, type_ctx),
        "static_item" => emit_named(node, args, ItemKind::Static, type_ctx),
        "type_item" | "associated_type" => emit_named(node, args, ItemKind::Type, type_ctx),
        "trait_item" => walk_trait(node, args),
        "impl_item" => walk_impl(node, args),
        "mod_item" => walk_mod(node, args),
        "macro_definition" => emit_macro(node, args),
        "use_declaration" => collect_use(
            node,
            args.source,
            args.file,
            args.module_path,
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

fn walk_trait(node: Node<'_>, args: &mut EmitArgs<'_>) {
    let Some(name) = field_text(node, "name", args.source) else {
        return;
    };
    let vis = visibility(node, args.source);
    emit_named(node, args, ItemKind::Trait, None);
    let Some(body) = node.child_by_field_name("body") else {
        return;
    };
    let tctx = TypeCtx {
        type_path: name,
        trait_path: None,
        default_vis: Some(vis),
    };
    walk_list(body, args, Some(&tctx));
}

fn walk_impl(node: Node<'_>, args: &mut EmitArgs<'_>) {
    let Some(ty) = node.child_by_field_name("type") else {
        return;
    };
    let type_path = type_as_written(ty, args.source);
    if type_path.is_empty() || generic_names(node, args.source).contains(&type_path) {
        return;
    }
    let trait_path = node
        .child_by_field_name("trait")
        .map(|n| type_as_written(n, args.source))
        .filter(|s| !s.is_empty());
    let tctx = TypeCtx {
        type_path,
        trait_path,
        default_vis: None,
    };
    if let Some(body) = node.child_by_field_name("body") {
        walk_list(body, args, Some(&tctx));
    }
}

fn walk_mod(node: Node<'_>, args: &mut EmitArgs<'_>) {
    let Some(name) = field_text(node, "name", args.source) else {
        return;
    };
    let mut child_path = args.module_path.to_vec();
    child_path.push(name.clone());
    emit_named(node, args, ItemKind::Mod, None);
    if let Some(body) = node.child_by_field_name("body") {
        let mut nested = EmitArgs {
            source: args.source,
            file: args.file,
            module_path: &child_path,
            ctx: args.ctx,
            out: args.out,
        };
        walk_list(body, &mut nested, None);
        return;
    }
    let path_attr = path_attribute(node, args.source);
    if let Some(resolved) =
        resolve_mod_file(args.file, &name, path_attr.as_deref(), &args.ctx.crate_root)
    {
        args.out.pending.push(PendingMod {
            file: resolved,
            module_path: child_path,
        });
    }
}

fn generic_names(node: Node<'_>, source: &str) -> Vec<String> {
    let Some(params) = node.child_by_field_name("type_parameters") else {
        return Vec::new();
    };
    let mut names = Vec::new();
    super::ts::each_named(params, |child| {
        let name = match child.kind() {
            "type_identifier" => Some(child),
            _ => child
                .child_by_field_name("left")
                .or_else(|| child.child_by_field_name("name")),
        };
        if let Some(n) = name
            && let Ok(text) = n.utf8_text(source.as_bytes())
        {
            names.push(text.to_string());
        }
    });
    names
}
