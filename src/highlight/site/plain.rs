use tree_sitter::Tree;

use super::common::word_start;
use super::{Position, Site, SiteAt};

pub fn plain(_: Option<&Tree>, text: &str, at: usize) -> SiteAt {
    let start = word_start(text, at, &['-']);
    SiteAt::new(
        Site::Identifier(Position::Unknown),
        text[start..at].to_string(),
        start,
        text,
        at,
    )
}
