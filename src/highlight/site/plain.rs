use tree_sitter::Tree;

use super::common::word_start;
use super::{Position, Site, SiteAt};

pub fn plain(_: Option<&Tree>, text: &str, at: usize) -> SiteAt {
    let start = word_start(text, at, &['-']);
    SiteAt {
        site: Site::Identifier(Position::Unknown),
        prefix: text[start..at].to_string(),
        replace_start: start,
    }
}
