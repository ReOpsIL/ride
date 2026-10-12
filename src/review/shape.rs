use sha2::{Digest, Sha256};

use crate::digest::hex;
use crate::highlight::{Lang, Leaf};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Digests {
    pub shape: String,
    pub code: String,
    pub scan: String,
}

pub fn digests(lang: Lang, leaves: &[Leaf], start: u32, end: u32) -> Digests {
    let mut shape_tokens = Vec::new();
    let mut code_tokens = Vec::new();
    for leaf in leaves {
        if leaf.end <= start || leaf.start >= end {
            continue;
        }
        match keep(lang, leaf) {
            Keep::Drop => {}
            Keep::Doc => shape_tokens.push(leaf.text.as_str()),
            Keep::Code => {
                shape_tokens.push(leaf.text.as_str());
                code_tokens.push(leaf.text.as_str());
            }
        }
    }
    Digests {
        shape: hash_tokens(&shape_tokens),
        code: hash_tokens(&code_tokens),
        scan: code_tokens.concat(),
    }
}

enum Keep {
    Drop,
    Doc,
    Code,
}

fn keep(lang: Lang, leaf: &Leaf) -> Keep {
    if leaf.text.chars().all(char::is_whitespace) {
        return Keep::Drop;
    }
    if is_comment(&leaf.kind) {
        if lang == Lang::Rust && rust_doc(&leaf.text) {
            return Keep::Doc;
        }
        return Keep::Drop;
    }
    Keep::Code
}

fn is_comment(kind: &str) -> bool {
    matches!(kind, "comment" | "line_comment" | "block_comment")
}

fn rust_doc(text: &str) -> bool {
    let text = text.trim_start();
    text.starts_with("///")
        || text.starts_with("//!")
        || text.starts_with("/*!")
        || (text.starts_with("/**") && !text.starts_with("/***"))
}

fn hash_tokens(tokens: &[&str]) -> String {
    let mut hasher = Sha256::new();
    for (index, token) in tokens.iter().enumerate() {
        if index > 0 {
            hasher.update([0]);
        }
        hasher.update(token.as_bytes());
    }
    hex(&hasher.finalize())
}

pub fn owned_start(lang: Lang, leaves: &[Leaf], item_start: u32) -> u32 {
    let window = item_start.saturating_sub(800);
    let between: Vec<&Leaf> = leaves
        .iter()
        .filter(|leaf| leaf.start >= window && leaf.end <= item_start)
        .filter(|leaf| !leaf.text.chars().all(char::is_whitespace))
        .collect();
    let mut start = item_start;
    let mut index = between.len();
    while index > 0 {
        let leaf = between[index - 1];
        if leaf.text == "]" {
            let Some(mark) = between[..index].iter().rposition(|item| item.text == "#") else {
                break;
            };
            start = between[mark].start;
            index = mark;
            continue;
        }
        if lang == Lang::Rust && is_comment(&leaf.kind) && rust_doc(&leaf.text) {
            start = leaf.start;
            index -= 1;
            continue;
        }
        break;
    }
    start
}

pub fn is_ident(kind: &str) -> bool {
    kind == "identifier" || kind.ends_with("_identifier")
}
