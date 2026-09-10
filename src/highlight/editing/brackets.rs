use tree_sitter::Node;

use crate::ffi::BracketPair;

use super::EditingKinds;

const OPEN: &[u8] = b"([{";
const CLOSE: &[u8] = b")]}";

type Span = (usize, usize);

pub fn pair(root: Node<'_>, text: &str, byte: usize, kinds: &EditingKinds) -> Option<BracketPair> {
    let bytes = text.as_bytes();
    let is_bracket = |b: &usize| {
        bytes
            .get(*b)
            .is_some_and(|c| OPEN.contains(c) || CLOSE.contains(c))
    };
    let at = [Some(byte), byte.checked_sub(1)]
        .into_iter()
        .flatten()
        .find(is_bracket)?;
    let skips = skip_ranges(root, kinds);
    if skips.iter().any(|&(s, e)| s <= at && at < e) {
        return None;
    }
    let c = bytes[at];
    if let Some(i) = OPEN.iter().position(|o| *o == c) {
        let close = forward(bytes, at, c, CLOSE[i], &skips)?;
        return Some(BracketPair {
            open_byte: at as u32,
            close_byte: close as u32,
        });
    }
    let i = CLOSE.iter().position(|o| *o == c)?;
    let open = backward(bytes, at, OPEN[i], c, &skips)?;
    Some(BracketPair {
        open_byte: open as u32,
        close_byte: at as u32,
    })
}

fn forward(bytes: &[u8], at: usize, open: u8, close: u8, skips: &[Span]) -> Option<usize> {
    let mut depth = 0usize;
    let mut i = at;
    let mut k = 0usize;
    while i < bytes.len() {
        while k < skips.len() && skips[k].1 <= i {
            k += 1;
        }
        if k < skips.len() && skips[k].0 <= i {
            i = skips[k].1;
            continue;
        }
        if bytes[i] == open {
            depth += 1;
        } else if bytes[i] == close {
            depth -= 1;
            if depth == 0 {
                return Some(i);
            }
        }
        i += 1;
    }
    None
}

fn backward(bytes: &[u8], at: usize, open: u8, close: u8, skips: &[Span]) -> Option<usize> {
    let mut depth = 0usize;
    let mut i = at;
    let mut k = skips.len();
    loop {
        while k > 0 && skips[k - 1].0 > i {
            k -= 1;
        }
        if k > 0 && skips[k - 1].1 > i {
            i = skips[k - 1].0.checked_sub(1)?;
            continue;
        }
        if bytes[i] == close {
            depth += 1;
        } else if bytes[i] == open {
            depth -= 1;
            if depth == 0 {
                return Some(i);
            }
        }
        i = i.checked_sub(1)?;
    }
}

fn skip_ranges(root: Node<'_>, kinds: &EditingKinds) -> Vec<Span> {
    let mut out = Vec::new();
    collect(root, kinds, &mut out);
    out
}

fn collect(node: Node<'_>, kinds: &EditingKinds, out: &mut Vec<Span>) {
    let kind = node.kind();
    if kinds.strings.contains(&kind) || kinds.comments.contains(&kind) {
        out.push((node.start_byte(), node.end_byte()));
        return;
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        collect(child, kinds, out);
    }
}
