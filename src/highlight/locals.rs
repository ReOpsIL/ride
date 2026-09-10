use std::collections::HashMap;

use tree_sitter::{Node, Tree};

use crate::ffi::{CompletionHit, ItemKind, OutlineItem};
use crate::score::{TIER_DECLARED, TIER_ITEM, TIER_MENTION};

use super::grammar::Grammar;
use super::members::matches;
use super::syntax::LocalQuery;
use super::walk::each_node;

pub type Declares = fn(Node<'_>, &str) -> bool;
pub type LocalDetail = fn(Node<'_>, &str) -> Option<String>;

pub fn hits(
    tree: &Tree,
    text: &str,
    outline: &[OutlineItem],
    q: &LocalQuery<'_>,
    grammar: &Grammar,
) -> Vec<CompletionHit> {
    let prefix = q.prefix;
    let limit = q.limit as usize;
    let typing_at = q.at as usize;
    let p = prefix.to_ascii_lowercase();
    let mut best: HashMap<String, CompletionHit> = HashMap::new();
    for item in outline {
        if matches(&item.name, &p) {
            offer(
                &mut best,
                CompletionHit::from_outline(item, TIER_ITEM, None),
            );
        }
    }
    each_node(tree.root_node(), &mut |node| {
        if !grammar.local_kinds.contains(&node.kind()) || node.start_byte() == typing_at {
            return;
        }
        let Ok(name) = node.utf8_text(text.as_bytes()) else {
            return;
        };
        if name.is_empty() || !matches(name, &p) {
            return;
        }
        let declared = (grammar.declares)(node, text);
        let tier = if declared {
            TIER_DECLARED
        } else {
            TIER_MENTION
        };
        let mut hit = CompletionHit::local(
            name,
            ItemKind::Local,
            tier,
            Some((node.start_byte() as u32, node.end_byte() as u32)),
        );
        if declared {
            hit.detail = (grammar.local_detail)(node, text).unwrap_or_default();
        }
        offer(&mut best, hit);
    });
    let mut out: Vec<CompletionHit> = best.into_values().collect();
    out.sort_by(|a, b| b.score.total_cmp(&a.score).then(a.name.cmp(&b.name)));
    out.truncate(limit);
    out
}

fn offer(best: &mut HashMap<String, CompletionHit>, hit: CompletionHit) {
    match best.get(&hit.name) {
        Some(prev) if prev.score >= hit.score => {}
        _ => {
            best.insert(hit.name.clone(), hit);
        }
    }
}

pub fn no_declares(_: Node<'_>, _: &str) -> bool {
    false
}

pub fn no_detail(_: Node<'_>, _: &str) -> Option<String> {
    None
}

pub fn within_field(parent: Node<'_>, field: &str, node: Node<'_>) -> bool {
    let mut cursor = parent.walk();
    parent
        .children_by_field_name(field, &mut cursor)
        .any(|f| f.start_byte() <= node.start_byte() && node.end_byte() <= f.end_byte())
}
