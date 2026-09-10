use std::collections::HashSet;
use std::path::{Path, PathBuf};

use thiserror::Error;
use tree_sitter::Parser;

use crate::ffi::ItemKind;
use crate::skip::under_root;

mod attrs;
mod cargo_toml;
mod docs;
mod emit;
mod external;
mod impls;
mod item;
mod mod_walk;
mod mods;
mod reach;
mod reexport;
mod scan;
mod ts;
mod types_walk;
mod use_walk;
mod variants;
mod vis;
mod walk;

pub use cargo_toml::{Package, parse_toml, read_package, workspace_members};
pub use external::External;
pub use item::{CrateContext, ItemDoc, ItemParts, Scope, Visibility};

use walk::PendingMod;

#[derive(Debug, Error)]
pub enum ExtractError {
    #[error("io {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("parse {path}: {message}")]
    Parse { path: PathBuf, message: String },
    #[error("language: {0}")]
    Language(String),
    #[error("toml {path}: {message}")]
    Toml { path: PathBuf, message: String },
}

pub fn rust_parser() -> Result<Parser, ExtractError> {
    let mut parser = Parser::new();
    parser
        .set_language(&tree_sitter_rust::LANGUAGE.into())
        .map_err(|e| ExtractError::Language(format!("{e:?}")))?;
    Ok(parser)
}

pub fn extract_source(
    source: &str,
    ctx: &CrateContext,
    module_path: &[String],
) -> Result<Vec<ItemDoc>, ExtractError> {
    let mut parser = rust_parser()?;
    let tree = parser
        .parse(source, None)
        .ok_or_else(|| ExtractError::Parse {
            path: PathBuf::from("<mem>"),
            message: "parse returned none".into(),
        })?;
    let file = Path::new("<mem>");
    let extracted = walk::extract_tree(tree.root_node(), source, file, module_path, true, ctx);
    let mut items = extracted.items;
    items.extend(reexport::apply(
        &items,
        &extracted.reexports,
        &External::default(),
        &extracted.crate_aliases,
    ));
    reach::resolve(&mut items, &extracted.assoc, ctx.scope);
    Ok(items)
}

pub fn extract_crate(crate_root: &Path, scope: Scope) -> Result<Vec<ItemDoc>, ExtractError> {
    extract_crate_with_version(crate_root, scope, None, &External::default())
}

pub fn extract_crate_with_version(
    crate_root: &Path,
    scope: Scope,
    version: Option<&str>,
    external: &External,
) -> Result<Vec<ItemDoc>, ExtractError> {
    let pkg = read_package(crate_root)?;
    let ctx = CrateContext {
        crate_name: pkg.name.clone(),
        crate_version: version
            .map(str::to_string)
            .unwrap_or_else(|| pkg.version.clone()),
        crate_root: crate_root.to_path_buf(),
        edition: pkg.edition.clone(),
        features: Vec::new(),
        scope,
    };
    let mut parser = rust_parser()?;
    let mut visited = HashSet::new();
    let mut items = Vec::new();
    let mut reexports = Vec::new();
    let mut aliases = Vec::new();
    let mut assoc = Vec::new();
    items.push(crate_item(&pkg, crate_root, &ctx));
    let mut queue: Vec<PendingMod> = pkg
        .entries
        .into_iter()
        .map(|file| PendingMod {
            file,
            module_path: vec![ctx.crate_name.clone()],
            reach: true,
        })
        .collect();
    while let Some(pending) = queue.pop() {
        let Ok(canon) = pending.file.canonicalize() else {
            continue;
        };
        if !visited.insert(canon.clone()) || !under_root(&canon, crate_root) {
            continue;
        }
        let Some(source) = scan::read_rs(&canon, &ctx.crate_name)? else {
            continue;
        };
        let Some(tree) = parser.parse(&source, None) else {
            continue;
        };
        let extracted = walk::extract_tree(
            tree.root_node(),
            &source,
            &canon,
            &pending.module_path,
            pending.reach,
            &ctx,
        );
        if pending.module_path.len() == 1
            && let Some(crate_doc) = items.iter_mut().find(|i| i.item_kind == ItemKind::Crate)
            && crate_doc.doc_first_paragraph.is_empty()
            && !extracted.inner_docs.is_empty()
        {
            crate_doc.doc_first_paragraph = extracted.inner_docs;
        }
        items.extend(extracted.items);
        reexports.extend(extracted.reexports);
        aliases.extend(extracted.crate_aliases);
        assoc.extend(extracted.assoc);
        visited.extend(
            extracted
                .excluded
                .iter()
                .filter_map(|f| f.canonicalize().ok()),
        );
        queue.extend(extracted.pending);
        if queue.is_empty() {
            queue.extend(
                scan::leftover_src_files(crate_root, &visited, &ctx)
                    .into_iter()
                    .map(|(file, module_path)| PendingMod {
                        file,
                        module_path,
                        reach: false,
                    }),
            );
        }
    }
    items.extend(reexport::apply(&items, &reexports, external, &aliases));
    reach::resolve(&mut items, &assoc, scope);
    Ok(items)
}

fn crate_item(pkg: &Package, crate_root: &Path, ctx: &CrateContext) -> ItemDoc {
    ItemDoc::from_ctx(
        ctx,
        ItemParts {
            kind: ItemKind::Crate,
            path: pkg.name.clone(),
            name: pkg.name.clone(),
            vis: Visibility::Pub,
            source_path: crate_root.join("Cargo.toml"),
            byte_range: (0, 0),
            signature: String::new(),
            doc: pkg.description.clone().unwrap_or_default(),
            chunk: String::new(),
            reachable: true,
            deprecated: false,
        },
    )
}
