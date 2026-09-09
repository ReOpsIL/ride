use std::path::Path;

use tree_sitter::Node;

use crate::ffi::ItemKind;

use super::docs::{preceding_docs, signature, source_chunk};
use super::item::{
    CrateContext, ItemDoc, ItemParts, Visibility, byte_range, field_text, join_path,
};
use super::vis::{effective_vis, has_attr, visibility};
use super::walk::{FileExtract, TypeCtx};

pub struct EmitArgs<'a> {
    pub source: &'a str,
    pub file: &'a Path,
    pub module_path: &'a [String],
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
    args.out
        .items
        .push(make_item(args, kind, path, name.clone(), vis, node));
    if let Some(trait_path) = type_ctx.and_then(|t| t.trait_path.as_ref()) {
        let path = format!("{trait_path}::{name}");
        args.out
            .items
            .push(make_item(args, kind, path, name, vis, node));
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
    args.out
        .items
        .push(make_item(args, kind, path, name, vis, node));
}

pub fn emit_macro(node: Node<'_>, args: &mut EmitArgs<'_>) {
    let Some(name) = field_text(node, "name", args.source) else {
        return;
    };
    let vis = if has_attr(node, args.source, "macro_export") {
        Visibility::Pub
    } else {
        visibility(node, args.source)
    };
    let path = join_path(args.module_path, &name);
    args.out
        .items
        .push(make_item(args, ItemKind::Macro, path, name, vis, node));
}

fn make_item(
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
        },
    )
}
