use std::path::Path;

use tree_sitter::Node;

use super::item::{Visibility, byte_range, field_text};
use super::reexport::{Reexport, ReexportKind, resolve_use_path};
use super::vis::visibility;

pub fn collect_use(
    node: Node<'_>,
    source: &str,
    file: &Path,
    module_path: &[String],
    reach: bool,
    out: &mut Vec<Reexport>,
) {
    let vis = visibility(node, source);
    if vis == Visibility::Private {
        return;
    }
    let Some(arg) = node.child_by_field_name("argument") else {
        return;
    };
    let ctx = UseCtx {
        module_path,
        vis,
        reach,
        file,
        range: byte_range(node),
    };
    collect_clause(arg, source, &ctx, &[], out);
}

struct UseCtx<'a> {
    module_path: &'a [String],
    vis: Visibility,
    reach: bool,
    file: &'a Path,
    range: (u32, u32),
}

fn collect_clause(
    node: Node<'_>,
    source: &str,
    ctx: &UseCtx<'_>,
    prefix: &[String],
    out: &mut Vec<Reexport>,
) {
    match node.kind() {
        "use_as_clause" => {
            let Some(path_node) = node.child_by_field_name("path") else {
                return;
            };
            let Some(alias) = field_text(node, "alias", source) else {
                return;
            };
            let mut parts = prefix.to_vec();
            parts.extend(path_parts(path_node, source));
            push_named(out, ctx, parts, alias);
        }
        "use_list" => {
            for i in 0..node.named_child_count() {
                if let Some(child) = super::ts::child_at(node, i) {
                    collect_clause(child, source, ctx, prefix, out);
                }
            }
        }
        "scoped_use_list" => {
            let mut next = prefix.to_vec();
            if let Some(path) = node.child_by_field_name("path") {
                next.extend(path_parts(path, source));
            }
            if let Some(list) = node.child_by_field_name("list") {
                collect_clause(list, source, ctx, &next, out);
            }
        }
        "use_wildcard" => {
            let mut parts = prefix.to_vec();
            parts.extend(path_parts(node, source));
            if parts.last().map(String::as_str) == Some("*") {
                parts.pop();
            }
            out.push(Reexport {
                module_path: ctx.module_path.to_vec(),
                vis: ctx.vis,
                reach: ctx.reach,
                source_path: ctx.file.to_path_buf(),
                byte_range: ctx.range,
                kind: ReexportKind::Glob {
                    module: resolve_use_path(ctx.module_path, &parts),
                },
            });
        }
        _ => {
            let mut parts = prefix.to_vec();
            parts.extend(path_parts(node, source));
            if let Some(alias) = parts.last().cloned() {
                push_named(out, ctx, parts, alias);
            }
        }
    }
}

fn push_named(out: &mut Vec<Reexport>, ctx: &UseCtx<'_>, parts: Vec<String>, alias: String) {
    out.push(Reexport {
        module_path: ctx.module_path.to_vec(),
        vis: ctx.vis,
        reach: ctx.reach,
        source_path: ctx.file.to_path_buf(),
        byte_range: ctx.range,
        kind: ReexportKind::Named {
            target: resolve_use_path(ctx.module_path, &parts),
            alias,
        },
    });
}

fn path_parts(node: Node<'_>, source: &str) -> Vec<String> {
    let text = node
        .utf8_text(source.as_bytes())
        .unwrap_or("")
        .replace(' ', "");
    text.split("::")
        .filter(|s| !s.is_empty() && *s != "*")
        .map(str::to_string)
        .collect()
}
