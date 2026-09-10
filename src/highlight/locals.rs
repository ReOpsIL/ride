use std::collections::HashSet;

use tree_sitter::Tree;

use crate::ffi::{CompletionHit, ItemKind, OutlineItem};

use super::members::{FIELD_SCORE, METHOD_SCORE, matches};
use super::walk::each_node;

pub fn hits(
    tree: &Tree,
    text: &str,
    outline: &[OutlineItem],
    prefix: &str,
    limit: usize,
    kinds: &[&str],
) -> Vec<CompletionHit> {
    let p = prefix.to_ascii_lowercase();
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for item in outline {
        if out.len() >= limit {
            return out;
        }
        if matches(&item.name, &p) && seen.insert(item.name.clone()) {
            out.push(CompletionHit::local(
                &item.name,
                item.kind,
                METHOD_SCORE,
                Some((item.start_byte, item.end_byte)),
            ));
        }
    }
    each_node(tree.root_node(), &mut |node| {
        if out.len() >= limit || !kinds.contains(&node.kind()) {
            return;
        }
        let Ok(name) = node.utf8_text(text.as_bytes()) else {
            return;
        };
        if matches(name, &p) && seen.insert(name.to_string()) {
            out.push(CompletionHit::local(
                name,
                ItemKind::Local,
                FIELD_SCORE,
                Some((node.start_byte() as u32, node.end_byte() as u32)),
            ));
        }
    });
    out
}
