use std::collections::HashSet;

use tree_sitter::{Node, Tree};

use crate::ffi::{CompletionHit, ItemKind, OutlineItem};

use super::grammar::Grammar;
use super::walk::each_node;

const RECEIVER_KINDS: &[&str] = &["identifier", "field_identifier", "this", "self"];
pub const METHOD_SCORE: f32 = crate::score::TIER_ITEM;
pub const FIELD_SCORE: f32 = crate::score::TIER_MENTION;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Access {
    pub type_name: Option<String>,
}

pub fn access_before<'a>(
    tree: &'a Tree,
    text: &str,
    at: usize,
    ops: &[&str],
) -> Option<Option<Node<'a>>> {
    let head = text.get(..at)?.trim_end_matches([' ', '\t']);
    let op = ops.iter().find(|op| head.ends_with(*op))?;
    let end = head.len() - op.len();
    if *op == "." && head[..end].ends_with('.') {
        return None;
    }
    let receiver = end
        .checked_sub(1)
        .and_then(|b| tree.root_node().descendant_for_byte_range(b, b))
        .filter(|n| n.end_byte() == end && RECEIVER_KINDS.contains(&n.kind()));
    Some(receiver)
}

pub fn fallback_hits(
    tree: &Tree,
    text: &str,
    outline: &[OutlineItem],
    prefix: &str,
    limit: usize,
    grammar: &Grammar,
) -> Vec<CompletionHit> {
    let p = prefix.to_ascii_lowercase();
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for item in outline.iter().filter(|o| o.kind == ItemKind::Method) {
        if out.len() >= limit {
            return out;
        }
        if matches(&item.name, &p) && seen.insert(item.name.clone()) {
            out.push(CompletionHit::local(
                &item.name,
                ItemKind::Method,
                METHOD_SCORE,
                Some((item.start_byte, item.end_byte)),
            ));
        }
    }
    each_node(tree.root_node(), &mut |node| {
        if out.len() >= limit || !grammar.member_kinds.contains(&node.kind()) {
            return;
        }
        let Ok(name) = node.utf8_text(text.as_bytes()) else {
            return;
        };
        if matches(name, &p) && seen.insert(name.to_string()) {
            out.push(CompletionHit::local(
                name,
                ItemKind::Field,
                FIELD_SCORE,
                Some((node.start_byte() as u32, node.end_byte() as u32)),
            ));
        }
    });
    out
}

pub fn matches(name: &str, prefix_lower: &str) -> bool {
    prefix_lower.is_empty() || name.to_ascii_lowercase().starts_with(prefix_lower)
}
