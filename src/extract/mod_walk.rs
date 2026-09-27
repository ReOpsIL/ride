use tree_sitter::Node;

use crate::ffi::ItemKind;

use super::attrs::path_attribute;
use super::emit::{EmitArgs, emit_named};
use super::item::{Visibility, field_text};
use super::mods::{ModFile, ModScope, resolve_mod_file};
use super::vis::visibility;
use super::walk::{PendingMod, walk_list};

pub fn walk_mod(node: Node<'_>, args: &mut EmitArgs<'_>, hidden: bool) {
    let Some(name) = field_text(node, "name", args.source) else {
        return;
    };
    let body = node.child_by_field_name("body");
    if hidden {
        if body.is_none()
            && let Some(found) = resolve(node, args, &name)
        {
            args.out.excluded.push(found.file);
        }
        return;
    }
    let mut child_path = args.module_path.to_vec();
    child_path.push(name.clone());
    let reach = args.reach && visibility(node, args.source) == Visibility::Pub;
    emit_named(node, args, ItemKind::Mod, None);
    if let Some(body) = body {
        let child_dir = args.mod_dir.join(&name);
        let mut nested = EmitArgs {
            source: args.source,
            file: args.file,
            mod_dir: &child_dir,
            inline: true,
            module_path: &child_path,
            reach,
            ctx: args.ctx,
            out: args.out,
        };
        walk_list(body, &mut nested, None);
        return;
    }
    if let Some(found) = resolve(node, args, &name) {
        args.out.pending.push(PendingMod {
            file: found.file,
            dir: found.dir,
            module_path: child_path,
            reach,
        });
    }
}

fn resolve(node: Node<'_>, args: &EmitArgs<'_>, name: &str) -> Option<ModFile> {
    let path_attr = path_attribute(node, args.source);
    let scope = ModScope {
        file: args.file,
        dir: args.mod_dir,
        inline: args.inline,
    };
    resolve_mod_file(scope, name, path_attr.as_deref(), &args.ctx.crate_root)
}
