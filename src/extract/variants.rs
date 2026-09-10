use tree_sitter::Node;

use crate::ffi::ItemKind;

use super::attrs::is_test_only;
use super::docs::tidy_signature;
use super::emit::{EmitArgs, make_item, push_item};
use super::item::{field_text, node_text};
use super::vis::visibility;

pub fn emit_variants(node: Node<'_>, args: &mut EmitArgs<'_>) {
    let Some(enum_name) = field_text(node, "name", args.source) else {
        return;
    };
    let Some(body) = node.child_by_field_name("body") else {
        return;
    };
    let vis = visibility(node, args.source);
    super::ts::each_named(body, |variant| {
        if variant.kind() != "enum_variant" || is_test_only(variant, args.source) {
            return;
        }
        let Some(name) = field_text(variant, "name", args.source) else {
            return;
        };
        let path = format!("{enum_name}::{name}");
        let mut item = make_item(args, ItemKind::Variant, path, name.clone(), vis, variant);
        item.signature = variant_signature(variant, &name, args.source);
        push_item(args, item, Some(&enum_name));
    });
}

fn variant_signature(variant: Node<'_>, name: &str, source: &str) -> String {
    match variant.child_by_field_name("body") {
        Some(body) if body.kind() == "field_declaration_list" => format!("{name} {{ .. }}"),
        _ => tidy_signature(&node_text(variant, source)),
    }
}
