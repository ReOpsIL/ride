use std::cmp::Reverse;

use tree_sitter::Node;

use crate::ffi::FoldRange;
use crate::text::{line_end, line_start};

pub fn after_line(text: &str, byte: usize) -> usize {
    (line_end(text, byte) + 1).min(text.len())
}

pub fn last_content(text: &str, start: usize, end: usize) -> usize {
    let end = end.min(text.len()).max(start);
    let trimmed = text[start..end].trim_end();
    start + last_char_start(trimmed)
}

fn last_char_start(text: &str) -> usize {
    text.char_indices().next_back().map_or(0, |(i, _)| i)
}

pub fn span(node: Node<'_>) -> (usize, usize) {
    (node.start_byte(), node.end_byte())
}

pub fn push(out: &mut Vec<FoldRange>, text: &str, start: usize, end: usize, kind: &str) {
    if start >= end || end > text.len() || text[start..end].matches('\n').count() < 2 {
        return;
    }
    out.push(FoldRange {
        start_byte: start as u32,
        end_byte: end as u32,
        kind: kind.to_string(),
    });
}

pub fn braced(out: &mut Vec<FoldRange>, text: &str, node: Node<'_>, kind: &str) {
    let (start, end) = span(node);
    if text.as_bytes().get(start) != Some(&b'{') {
        return;
    }
    let close = last_content(text, start, end);
    push(out, text, start + 1, line_start(text, close), kind);
}

pub fn region(out: &mut Vec<FoldRange>, text: &str, head: usize, end: usize, kind: &str) {
    let last = last_content(text, head, end);
    push(
        out,
        text,
        line_end(text, head),
        after_line(text, last),
        kind,
    );
}

pub fn closed(out: &mut Vec<FoldRange>, text: &str, start: usize, end: usize, kind: &str) {
    between(out, text, &[start], last_content(text, start, end), kind);
}

pub fn between(out: &mut Vec<FoldRange>, text: &str, starts: &[usize], close: usize, kind: &str) {
    for (i, &head) in starts.iter().enumerate() {
        let next = starts.get(i + 1).copied().unwrap_or(close);
        push(
            out,
            text,
            line_end(text, head),
            line_start(text, next),
            kind,
        );
    }
}

pub fn runs(out: &mut Vec<FoldRange>, text: &str, spans: &[(usize, usize)], kind: &str) {
    let mut run: Vec<(usize, usize)> = Vec::new();
    for &(start, end) in spans {
        let whole = starts_line(text, start);
        let continues = whole
            && run.last().is_some_and(|&(_, prev)| {
                line_start(text, start) == after_line(text, last_char_start(&text[..prev]))
            });
        if !continues {
            flush(out, text, &run, kind);
            run.clear();
        }
        if whole {
            run.push((start, end));
        }
    }
    flush(out, text, &run, kind);
}

fn starts_line(text: &str, start: usize) -> bool {
    text[line_start(text, start)..start].trim().is_empty()
}

fn flush(out: &mut Vec<FoldRange>, text: &str, run: &[(usize, usize)], kind: &str) {
    if let (Some(&(head, _)), Some(&(_, end))) = (run.first(), run.last())
        && run.len() >= 3
    {
        region(out, text, head, end, kind);
    }
}

pub fn finish(mut out: Vec<FoldRange>) -> Vec<FoldRange> {
    out.sort_by_key(|f| (f.start_byte, Reverse(f.end_byte)));
    out.dedup_by(|a, b| a.start_byte == b.start_byte && a.end_byte == b.end_byte);
    out
}
