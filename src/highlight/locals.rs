use std::collections::HashSet;

use tree_sitter::{Node, Tree};

use crate::ffi::{CompletionHit, ItemKind, OutlineItem};

pub fn hits(
    tree: &Tree,
    text: &str,
    outline: &[OutlineItem],
    prefix: &str,
    limit: u32,
) -> Vec<CompletionHit> {
    let cap = limit as usize;
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    let p = prefix.to_ascii_lowercase();
    for item in outline {
        if out.len() >= cap {
            return out;
        }
        if !matches_prefix(&item.name, &p) {
            continue;
        }
        if !seen.insert(item.name.clone()) {
            continue;
        }
        out.push(hit(
            &item.name,
            item.kind,
            45.0,
            Some(item.start_byte),
            Some(item.end_byte),
        ));
    }
    collect_idents(tree.root_node(), text, &p, &mut seen, &mut out, cap);
    out
}

fn collect_idents(
    node: Node<'_>,
    text: &str,
    prefix: &str,
    seen: &mut HashSet<String>,
    out: &mut Vec<CompletionHit>,
    cap: usize,
) {
    if out.len() >= cap {
        return;
    }
    if matches!(node.kind(), "identifier" | "type_identifier")
        && let Ok(name) = node.utf8_text(text.as_bytes())
        && matches_prefix(name, prefix)
        && seen.insert(name.to_string())
    {
        out.push(hit(
            name,
            ItemKind::Local,
            40.0,
            Some(node.start_byte() as u32),
            Some(node.end_byte() as u32),
        ));
    }
    for i in 0..node.named_child_count() {
        if let Some(child) = node.named_child(u32::try_from(i).unwrap_or(u32::MAX)) {
            collect_idents(child, text, prefix, seen, out, cap);
        }
    }
}

fn matches_prefix(name: &str, prefix: &str) -> bool {
    prefix.is_empty() || name.to_ascii_lowercase().starts_with(prefix)
}

fn hit(
    name: &str,
    kind: ItemKind,
    score: f32,
    start: Option<u32>,
    end: Option<u32>,
) -> CompletionHit {
    CompletionHit {
        path: name.to_string(),
        name: name.to_string(),
        insert_text: name.to_string(),
        item_kind: kind,
        crate_name: String::new(),
        crate_version: String::new(),
        signature: String::new(),
        doc_first_sentence: String::new(),
        doc_paragraph: String::new(),
        source_path: None,
        byte_start: start,
        byte_end: end,
        score,
    }
}
