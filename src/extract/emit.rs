use std::path::Path;

use tree_sitter::Node;

use crate::ffi::ItemKind;

use super::attrs::{derive_name, has_attr, is_deprecated};
use super::docs::{preceding_docs, signature, source_chunk};
use super::item::{
    CrateContext, ItemDoc, ItemParts, Visibility, byte_range, field_text, join_path,
};
use super::reach::Assoc;
use super::vis::{effective_vis, visibility};
use super::walk::{FileExtract, TypeCtx};

pub struct EmitArgs<'a> {
    pub source: &'a str,
    pub file: &'a Path,
    pub module_path: &'a [String],
    pub reach: bool,
    pub ctx: &'a CrateContext,
    pub out: &'a mut FileExtract,
}

pub fn emit_fn(node: Node<'_>, args: &mut EmitArgs<'_>, type_ctx: Option<&TypeCtx>) {
    let Some(name) = field_text(node, "name", args.source) else {
        return;
    };
    let vis = effective_vis(
        visibility(node, args.source),
        type_ctx.and_then(|t| t.default_vis),
        type_ctx.is_some_and(|t| t.trait_path.is_some()),
    );
    let kind = if type_ctx.is_some() {
        ItemKind::Method
    } else {
        ItemKind::Fn
    };
    let path = match type_ctx {
        Some(t) => format!("{}::{name}", t.type_path),
        None => join_path(args.module_path, &name),
    };
    let item = make_item(args, kind, path, name.clone(), vis, node);
    push_item(args, item, type_ctx.map(|t| t.type_path.as_str()));
    if type_ctx.is_none()
        && let Some(derive) = derive_name(node, args.source)
    {
        let path = join_path(args.module_path, &derive);
        let mut item = make_item(args, ItemKind::Macro, path, derive, Visibility::Pub, node);
        item.reachable = true;
        args.out.items.push(item);
    }
    if let Some(trait_path) = type_ctx.and_then(|t| t.trait_path.as_deref()) {
        let path = format!("{trait_path}::{name}");
        let item = make_item(args, kind, path, name, vis, node);
        push_item(args, item, Some(trait_path));
    }
}

pub fn emit_named(
    node: Node<'_>,
    args: &mut EmitArgs<'_>,
    kind: ItemKind,
    type_ctx: Option<&TypeCtx>,
) {
    let Some(name) = field_text(node, "name", args.source) else {
        return;
    };
    let vis = effective_vis(
        visibility(node, args.source),
        type_ctx.and_then(|t| t.default_vis),
        type_ctx.is_some_and(|t| t.trait_path.is_some()),
    );
    let path = match type_ctx {
        Some(t) => format!("{}::{name}", t.type_path),
        None => join_path(args.module_path, &name),
    };
    let item = make_item(args, kind, path, name, vis, node);
    push_item(args, item, type_ctx.map(|t| t.type_path.as_str()));
}

pub fn emit_macro(node: Node<'_>, args: &mut EmitArgs<'_>) {
    let Some(name) = field_text(node, "name", args.source) else {
        return;
    };
    let exported = has_attr(node, args.source, "macro_export");
    let vis = if exported {
        Visibility::Pub
    } else {
        visibility(node, args.source)
    };
    let path = join_path(args.module_path, &name);
    let mut item = make_item(args, ItemKind::Macro, path, name, vis, node);
    item.reachable |= exported;
    args.out.items.push(item);
}

pub fn make_item(
    args: &EmitArgs<'_>,
    kind: ItemKind,
    path: String,
    name: String,
    vis: Visibility,
    node: Node<'_>,
) -> ItemDoc {
    ItemDoc::from_ctx(
        args.ctx,
        ItemParts {
            kind,
            path,
            name,
            vis,
            source_path: args.file.to_path_buf(),
            byte_range: byte_range(node),
            signature: signature(node, args.source),
            doc: preceding_docs(node, args.source),
            chunk: source_chunk(node, args.source),
            reachable: args.reach && vis == Visibility::Pub,
            deprecated: is_deprecated(node, args.source),
        },
    )
}

pub fn push_item(args: &mut EmitArgs<'_>, item: ItemDoc, owner: Option<&str>) {
    if let Some(owner) = owner {
        args.out.assoc.push(Assoc {
            path: item.path.clone(),
            owner: owner.to_string(),
        });
    }
    args.out.items.push(item);
}
