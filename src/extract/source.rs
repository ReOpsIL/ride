use std::path::{Path, PathBuf};

use tree_sitter::{Node, Parser};

use super::error::ExtractError;
use super::external::External;
use super::item::{CrateContext, ItemDoc};
use super::reach;
use super::reexport;
use super::walk::{self, TreeInput};

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
    Ok(extract_parsed(tree.root_node(), source, ctx, module_path))
}

pub fn extract_parsed(
    root: Node<'_>,
    source: &str,
    ctx: &CrateContext,
    module_path: &[String],
) -> Vec<ItemDoc> {
    let input = TreeInput {
        source,
        file: Path::new("<mem>"),
        mod_dir: Path::new(""),
        module_path,
        reach: true,
    };
    let extracted = walk::extract_tree(root, input, ctx);
    let mut items = extracted.items;
    let applied = reexport::apply(
        &items,
        &extracted.reexports,
        &External::default(),
        &extracted.crate_aliases,
    );
    items.extend(applied.items);
    reach::resolve(&mut items, &extracted.assoc, ctx.scope);
    items
}
