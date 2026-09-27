use std::collections::HashSet;
use std::path::{Path, PathBuf};

use tree_sitter::Parser;

use crate::ffi::ItemKind;
use crate::skip::under_root;

use super::cargo_toml::{Package, read_package};
use super::crate_extract::{CrateExtract, crate_item, plain};
use super::error::ExtractError;
use super::external::External;
use super::item::{CrateContext, ItemDoc, Scope};
use super::mods::{inferred_dir, root_dir};
use super::scan;
use super::source::rust_parser;
use super::walk::{self, FileExtract, PendingMod, TreeInput};

struct CrateWalk<'a> {
    crate_root: &'a Path,
    ctx: CrateContext,
    parser: Parser,
    visited: HashSet<PathBuf>,
    queue: Vec<PendingMod>,
    acc: CrateExtract,
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
    Ok(extract_crate_parts(crate_root, scope, version)?
        .finish(external)
        .items)
}

pub fn extract_crate_parts(
    crate_root: &Path,
    scope: Scope,
    version: Option<&str>,
) -> Result<CrateExtract, ExtractError> {
    let pkg = read_package(crate_root)?;
    let ctx = context(&pkg, crate_root, scope, version);
    let mut walk = CrateWalk {
        crate_root,
        parser: rust_parser()?,
        visited: HashSet::new(),
        queue: entry_mods(&pkg.entries, &ctx.crate_name),
        acc: plain(
            vec![crate_item(&pkg, crate_root, &ctx)],
            ctx.crate_name.clone(),
            scope,
        ),
        ctx,
    };
    while let Some(pending) = walk.queue.pop() {
        walk.visit(pending)?;
        if walk.queue.is_empty() {
            walk.queue_leftovers();
        }
    }
    Ok(walk.acc)
}

fn context(pkg: &Package, crate_root: &Path, scope: Scope, version: Option<&str>) -> CrateContext {
    CrateContext {
        crate_name: pkg.name.clone(),
        crate_version: version.map_or_else(|| pkg.version.clone(), str::to_string),
        crate_root: crate_root.to_path_buf(),
        edition: pkg.edition.clone(),
        features: Vec::new(),
        scope,
    }
}

fn entry_mods(entries: &[PathBuf], crate_name: &str) -> Vec<PendingMod> {
    entries
        .iter()
        .map(|file| PendingMod {
            dir: root_dir(file),
            file: file.clone(),
            module_path: vec![crate_name.to_string()],
            reach: true,
        })
        .collect()
}

impl CrateWalk<'_> {
    fn visit(&mut self, pending: PendingMod) -> Result<(), ExtractError> {
        let Ok(canon) = pending.file.canonicalize() else {
            return Ok(());
        };
        if !self.visited.insert(canon.clone()) || !under_root(&canon, self.crate_root) {
            return Ok(());
        }
        let Some(source) = scan::read_rs(&canon, &self.ctx.crate_name)? else {
            return Ok(());
        };
        let Some(tree) = self.parser.parse(&source, None) else {
            return Ok(());
        };
        let input = TreeInput {
            source: &source,
            file: &canon,
            mod_dir: &pending.dir,
            module_path: &pending.module_path,
            reach: pending.reach,
        };
        let extracted = walk::extract_tree(tree.root_node(), input, &self.ctx);
        self.absorb(extracted, pending.module_path.len() == 1);
        Ok(())
    }

    fn absorb(&mut self, extracted: FileExtract, crate_root_file: bool) {
        if crate_root_file {
            self.adopt_crate_docs(extracted.inner_docs);
        }
        self.acc.items.extend(extracted.items);
        self.acc.reexports.extend(extracted.reexports);
        self.acc.aliases.extend(extracted.crate_aliases);
        self.acc.assoc.extend(extracted.assoc);
        let excluded = extracted
            .excluded
            .iter()
            .filter_map(|f| f.canonicalize().ok());
        self.visited.extend(excluded);
        self.queue.extend(extracted.pending);
    }

    fn adopt_crate_docs(&mut self, docs: String) {
        if docs.is_empty() {
            return;
        }
        if let Some(crate_doc) = self
            .acc
            .items
            .iter_mut()
            .find(|i| i.item_kind == ItemKind::Crate)
            && crate_doc.doc_first_paragraph.is_empty()
        {
            crate_doc.doc_first_paragraph = docs;
        }
    }

    fn queue_leftovers(&mut self) {
        let mut leftovers = scan::leftover_src_files(self.crate_root, &self.visited, &self.ctx);
        leftovers.sort_by(|a, b| b.1.len().cmp(&a.1.len()).then_with(|| b.0.cmp(&a.0)));
        self.queue
            .extend(leftovers.into_iter().map(|(file, module_path)| PendingMod {
                dir: inferred_dir(&file),
                file,
                module_path,
                reach: false,
            }));
    }
}
