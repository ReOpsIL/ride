use crate::error::EngineError;
use crate::ffi::OutlineItem;

use super::lang::Lang;
use super::leaves::Leaf;
use super::syntax;

pub struct ParsedSource {
    pub outline: Vec<OutlineItem>,
    pub leaves: Vec<Leaf>,
}

pub fn parse_source(lang: Lang, text: &str) -> Result<ParsedSource, EngineError> {
    let mut syntax = syntax::make(lang)?;
    syntax.parse_full(text)?;
    let mut outline = syntax.outline(text);
    outline.extend(syntax.hidden_items(text, &outline));
    outline.sort_by_key(|item| item.start_byte);
    Ok(ParsedSource {
        outline,
        leaves: syntax.leaves(text),
    })
}
