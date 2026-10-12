use std::collections::HashMap;

use crate::ffi::{ItemKind, OutlineItem};
use crate::highlight::{Lang, Leaf};
use crate::text::floor_char_boundary;

use super::shape::{self, Digests};

#[derive(Debug, Clone)]
pub(crate) struct ParsedItem {
    pub item: String,
    pub name: String,
    pub kind: String,
    pub signature: String,
    pub doc: String,
    pub start: u32,
    pub end: u32,
    pub line: u32,
    pub end_line: u32,
    pub shape: String,
    pub code: String,
    pub scan: String,
    pub is_test: bool,
}

pub(crate) fn parse_items(
    path: &str,
    lang: Lang,
    text: &str,
    outline: &[OutlineItem],
    leaves: &[Leaf],
) -> Vec<ParsedItem> {
    let chains = chains(outline);
    let labels: Vec<&str> = outline.iter().map(|item| kind_label(item.kind)).collect();
    let mut counts: HashMap<(String, &str), u32> = HashMap::new();
    for (chain, label) in chains.iter().zip(&labels) {
        *counts.entry((chain.join("::"), *label)).or_default() += 1;
    }
    outline
        .iter()
        .enumerate()
        .map(|(index, item)| {
            let chain = &chains[index];
            let label = labels[index];
            let collided = counts[&(chain.join("::"), label)] > 1;
            let hash_from = shape::owned_start(lang, leaves, item.start_byte);
            let digested = shape::digests(lang, leaves, hash_from, item.end_byte);
            item_from(path, text, item, chain, label, collided, digested)
        })
        .collect()
}

fn item_from(
    path: &str,
    text: &str,
    item: &OutlineItem,
    chain: &[String],
    label: &str,
    collided: bool,
    digested: Digests,
) -> ParsedItem {
    let (line, end_line) = line_span(text, item.start_byte, item.end_byte);
    ParsedItem {
        item: item_string(chain, &item.signature, collided),
        name: item.name.clone(),
        kind: label.to_string(),
        signature: item.signature.clone(),
        doc: item.doc.clone(),
        start: item.start_byte,
        end: item.end_byte,
        line,
        end_line,
        shape: digested.shape,
        code: digested.code,
        is_test: is_test(path, &digested.scan),
        scan: digested.scan,
    }
}

fn item_string(chain: &[String], signature: &str, collided: bool) -> String {
    let base = chain.join("::");
    if collided && !signature.is_empty() {
        format!("{base} ({signature})")
    } else {
        base
    }
}

fn chains(outline: &[OutlineItem]) -> Vec<Vec<String>> {
    outline
        .iter()
        .enumerate()
        .map(|(index, item)| {
            let mut parents: Vec<(u32, String)> = outline
                .iter()
                .enumerate()
                .filter(|(other_index, other)| {
                    *other_index != index
                        && other.start_byte <= item.start_byte
                        && other.end_byte >= item.end_byte
                        && other.end_byte.saturating_sub(other.start_byte)
                            > item.end_byte.saturating_sub(item.start_byte)
                })
                .map(|(_, other)| (other.start_byte, other.name.clone()))
                .collect();
            parents.sort_by_key(|parent| parent.0);
            let mut chain: Vec<String> = parents.into_iter().map(|parent| parent.1).collect();
            chain.push(item.name.clone());
            chain
        })
        .collect()
}

pub fn kind_label(kind: ItemKind) -> &'static str {
    match kind {
        ItemKind::Fn => "fn",
        ItemKind::Method => "method",
        ItemKind::Struct => "struct",
        ItemKind::Enum => "enum",
        ItemKind::Union => "union",
        ItemKind::Trait => "trait",
        ItemKind::Mod => "mod",
        ItemKind::Type => "type",
        ItemKind::Const => "const",
        ItemKind::Static => "static",
        ItemKind::Macro => "macro",
        ItemKind::Class => "class",
        ItemKind::Namespace => "namespace",
        ItemKind::Field => "field",
        ItemKind::Variant => "variant",
        ItemKind::Header => "header",
        ItemKind::Keyword
        | ItemKind::Local
        | ItemKind::Crate
        | ItemKind::Heading
        | ItemKind::Table
        | ItemKind::Target => "item",
    }
}

pub fn line_span(text: &str, start: u32, end: u32) -> (u32, u32) {
    let start = floor_char_boundary(text, (start as usize).min(text.len()));
    let end = floor_char_boundary(text, (end as usize).min(text.len()));
    let line = |at: usize| text[..at].bytes().filter(|byte| *byte == b'\n').count() as u32 + 1;
    let first = line(start);
    (first, line(end).max(first))
}

fn is_test(path: &str, scan: &str) -> bool {
    test_path(path) || scan.contains("#[test") || scan.contains("#[tokio::test")
}

pub fn test_path(path: &str) -> bool {
    path.split(['/', '\\']).any(|part| part == "tests")
}

pub fn calls_in(leaves: &[Leaf], start: u32, end: u32, own: &str) -> Vec<String> {
    let inside: Vec<&Leaf> = leaves
        .iter()
        .filter(|leaf| leaf.start >= start && leaf.end <= end)
        .collect();
    let mut names = Vec::new();
    for pair in inside.windows(2) {
        if shape::is_ident(&pair[0].kind)
            && pair[1].text == "("
            && pair[0].text != own
            && !names.contains(&pair[0].text)
        {
            names.push(pair[0].text.clone());
        }
    }
    names
}
