use tree_sitter::Node;

use crate::ffi::ItemKind;

use super::emit::{EmitArgs, emit_named};
use super::impls::type_as_written;
use super::item::field_text;
use super::vis::visibility;
use super::walk::{TypeCtx, walk_list};

pub fn walk_trait(node: Node<'_>, args: &mut EmitArgs<'_>) {
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

pub fn walk_impl(node: Node<'_>, args: &mut EmitArgs<'_>) {
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
