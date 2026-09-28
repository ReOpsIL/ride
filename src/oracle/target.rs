use std::path::{Path, PathBuf};

use super::job::DocText;
use super::lsp::{Encoding, Spot, byte_at};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Target {
    pub path: PathBuf,
    pub name_byte: usize,
    pub text: String,
}

pub fn targets(spots: Vec<Spot>, encoding: Encoding, known: &[&DocText]) -> Vec<Target> {
    spots
        .into_iter()
        .filter_map(|spot| {
            let text = text_of(&spot.path, known)?;
            let name_byte = byte_at(&text, spot.line, spot.character, encoding);
            Some(Target {
                path: spot.path,
                name_byte,
                text,
            })
        })
        .collect()
}

fn text_of(path: &Path, known: &[&DocText]) -> Option<String> {
    let real = std::fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let open = known
        .iter()
        .find(|doc| std::fs::canonicalize(&doc.path).unwrap_or_else(|_| doc.path.clone()) == real);
    match open {
        Some(doc) => Some(doc.text.clone()),
        None => std::fs::read_to_string(path).ok(),
    }
}
