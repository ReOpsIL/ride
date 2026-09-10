use tree_sitter::Node;

use crate::ffi::ByteRange;

use super::EditingKinds;

const MARKDOWN: &[&str] = &["paragraph", "list_item", "section", "document"];

type Span = (usize, usize);

pub fn ranges(
    root: Node<'_>,
    text: &str,
    range: ByteRange,
    kinds: &EditingKinds,
) -> Vec<ByteRange> {
    collect(root, text, range, &|node| candidates(node, text, kinds))
}

pub fn markdown(root: Node<'_>, text: &str, range: ByteRange) -> Vec<ByteRange> {
    collect(root, text, range, &|node| {
        MARKDOWN
            .contains(&node.kind())
            .then(|| trimmed(text, node.start_byte(), node.end_byte()))
            .into_iter()
            .collect()
    })
}

fn collect(
    root: Node<'_>,
    text: &str,
    range: ByteRange,
    expand: &dyn Fn(Node<'_>) -> Vec<Span>,
) -> Vec<ByteRange> {
    let len = text.len();
    let start = (range.start_byte as usize).min(len);
    let end = (range.end_byte as usize).min(len).max(start);
    let mut grow = Growth {
        original: (start, end),
        out: Vec::new(),
    };
    let word = (start == end).then(|| word_at(text, start)).flatten();
    if let Some(word) = word {
        grow.push(word);
    }
    let (qs, qe) = word.unwrap_or((start, end));
    let mut node = Some(root.descendant_for_byte_range(qs, qe).unwrap_or(root));
    while let Some(n) = node {
        for span in expand(n) {
            grow.push(span);
        }
        node = n.parent();
    }
    grow.push((0, len));
    grow.out
}

struct Growth {
    original: Span,
    out: Vec<ByteRange>,
}

impl Growth {
    fn push(&mut self, (s, e): Span) {
        let (os, oe) = self.original;
        let covers = s <= os && e >= oe && (s, e) != (os, oe);
        let grows = self.out.last().is_none_or(|l| {
            s <= l.start_byte as usize
                && e >= l.end_byte as usize
                && (s, e) != (l.start_byte as usize, l.end_byte as usize)
        });
        if covers && grows {
            self.out.push(ByteRange {
                start_byte: s as u32,
                end_byte: e as u32,
            });
        }
    }
}

fn candidates(node: Node<'_>, text: &str, kinds: &EditingKinds) -> Vec<Span> {
    let whole = (node.start_byte(), node.end_byte());
    let inner = if kinds.strings.contains(&node.kind()) {
        string_inner(node, text)
    } else if kinds.bodies.contains(&node.kind()) {
        body_inner(text, whole)
    } else {
        None
    };
    inner.into_iter().chain(std::iter::once(whole)).collect()
}

fn string_inner(node: Node<'_>, text: &str) -> Option<Span> {
    let mut cursor = node.walk();
    let parts: Vec<Node<'_>> = node
        .named_children(&mut cursor)
        .filter(|c| !c.kind().ends_with("_open") && !c.kind().ends_with("_close"))
        .collect();
    match (parts.first(), parts.last()) {
        (Some(first), Some(last)) => Some((first.start_byte(), last.end_byte())),
        _ => unquoted(text, (node.start_byte(), node.end_byte())),
    }
}

fn unquoted(text: &str, (start, end): Span) -> Option<Span> {
    let body = &text[start..end];
    let open = body.find(['"', '\''])?;
    let quote = body.as_bytes()[open];
    let leading = body[open..].bytes().take_while(|b| *b == quote).count();
    let trailing = body.bytes().rev().take_while(|b| *b == quote).count();
    let k = leading.min(trailing).min((body.len() - open) / 2);
    let (s, e) = (start + open + k, end - k);
    (s < e).then_some((s, e))
}

fn body_inner(text: &str, (start, end): Span) -> Option<Span> {
    let bytes = text.as_bytes();
    let pair = matches!(
        (bytes.get(start), bytes.get(end.checked_sub(1)?)),
        (Some(b'{'), Some(b'}')) | (Some(b'('), Some(b')')) | (Some(b'['), Some(b']'))
    );
    if !pair || end - start < 2 {
        return None;
    }
    let (s, e) = trimmed(text, start + 1, end - 1);
    (s < e).then_some((s, e))
}

fn trimmed(text: &str, start: usize, end: usize) -> Span {
    let body = &text[start..end];
    let lead = body.len() - body.trim_start().len();
    let trail = body.len() - body.trim_end().len();
    let s = start + lead;
    (s, (end - trail).max(s))
}

fn word_at(text: &str, at: usize) -> Option<Span> {
    let is_word = |c: char| c.is_alphanumeric() || c == '_';
    let start = text[..at].trim_end_matches(is_word).len();
    let end = at + (text[at..].len() - text[at..].trim_start_matches(is_word).len());
    (start < end).then_some((start, end))
}
