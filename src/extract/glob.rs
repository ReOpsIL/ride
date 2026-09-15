use super::external::External;
use super::item::{ItemDoc, Visibility, join_path};
use super::reexport::{Reexport, dealias, exported};

pub const GLOB_LIMIT: usize = 20_000;

#[derive(Default)]
pub struct Globbed {
    pub items: Vec<ItemDoc>,
    pub oversized: Option<String>,
}

pub fn expand(
    items: &[ItemDoc],
    extra: &[ItemDoc],
    external: &External,
    aliases: &[(String, String)],
    re: &Reexport,
    module: &[String],
) -> Globbed {
    let local = local_children(items, extra, re, module);
    let target = dealias(module, aliases);
    if same_crate(root_of(&target), host_crate(items)) {
        return Globbed {
            items: local,
            oversized: None,
        };
    }
    match external.under_prefix(&target, GLOB_LIMIT) {
        Some(found) => {
            let mut out = local;
            out.extend(
                found
                    .into_iter()
                    .map(|src| mirror(items, src, re, &rerooted(re, &target, &src.path))),
            );
            Globbed {
                items: out,
                oversized: None,
            }
        }
        None => Globbed {
            items: Vec::new(),
            oversized: Some(target),
        },
    }
}

fn local_children(
    items: &[ItemDoc],
    extra: &[ItemDoc],
    re: &Reexport,
    module: &[String],
) -> Vec<ItemDoc> {
    let prefix = format!("{}::", module.join("::"));
    let depth = module.len() + 1;
    items
        .iter()
        .chain(extra.iter())
        .filter(|i| {
            i.visibility == Visibility::Pub
                && i.path.starts_with(&prefix)
                && i.path.split("::").count() == depth
        })
        .map(|src| mirror(items, src, re, &join_path(&re.module_path, &src.name)))
        .collect()
}

fn mirror(items: &[ItemDoc], src: &ItemDoc, re: &Reexport, path: &str) -> ItemDoc {
    let mut doc = src.clone();
    doc.path = path.to_string();
    doc.visibility = re.vis;
    doc.reachable = exported(re);
    if let Some(host) = items.first() {
        doc.crate_name = host.crate_name.clone();
        doc.crate_version = host.crate_version.clone();
        doc.edition = host.edition.clone();
        doc.scope = host.scope;
    }
    doc
}

fn rerooted(re: &Reexport, target: &str, path: &str) -> String {
    let rest = path.get(target.len() + 2..).unwrap_or_default();
    format!("{}::{rest}", re.module_path.join("::"))
}

fn host_crate(items: &[ItemDoc]) -> &str {
    items.first().map(|i| i.crate_name.as_str()).unwrap_or("")
}

fn same_crate(a: &str, b: &str) -> bool {
    a.replace('-', "_") == b.replace('-', "_")
}

fn root_of(path: &str) -> &str {
    path.split("::").next().unwrap_or(path)
}
