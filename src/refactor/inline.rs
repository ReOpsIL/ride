use crate::ffi::{ByteRange, ExtractPlan, TextEdit};
use crate::highlight::{BufferSession, Lang};

use super::uses::InlineUse;

pub fn inline_variable(session: &BufferSession, cursor_byte: u32) -> Option<ExtractPlan> {
    if !matches!(session.lang(), Lang::Rust | Lang::C | Lang::Cpp) {
        return None;
    }
    let text = session.replica();
    let spans = session.inline_spans(cursor_byte)?;
    let init = slice(text, spans.init)?;
    let name = slice(text, spans.name)?.to_string();
    let first = spans.uses.first()?;
    let (removal_start, removal_end) = removal(text, spans.statement)?;
    if removal_end > first.range.start_byte {
        return None;
    }
    let mut edits = vec![TextEdit {
        start_byte: removal_start,
        end_byte: removal_end,
        text: String::new(),
        caret_byte: removal_start,
    }];
    edits.extend(spans.uses.iter().map(|u| TextEdit {
        start_byte: u.range.start_byte,
        end_byte: u.range.end_byte,
        text: replacement(u, init, &name),
        caret_byte: u.range.start_byte,
    }));
    let select_start = first
        .range
        .start_byte
        .checked_sub(removal_end - removal_start)?;
    let select_end = select_start + replacement(first, init, &name).len() as u32;
    Some(ExtractPlan {
        edits,
        name,
        select_start,
        select_end,
    })
}

fn slice(text: &str, range: ByteRange) -> Option<&str> {
    text.get(range.start_byte as usize..range.end_byte as usize)
}

fn replacement(use_: &InlineUse, init: &str, name: &str) -> String {
    if use_.shorthand {
        format!("{name}: {init}")
    } else if use_.parenthesize {
        format!("({init})")
    } else {
        init.to_string()
    }
}

fn removal(text: &str, statement: ByteRange) -> Option<(u32, u32)> {
    let start = statement.start_byte as usize;
    let end = statement.end_byte as usize;
    let line_start = text.get(..start)?.rfind('\n').map_or(0, |i| i + 1);
    let head = text.get(line_start..start)?;
    let rest = text.get(end..)?;
    let line_end = rest.find('\n').map_or(text.len(), |i| end + i + 1);
    let tail = text.get(end..line_end)?;
    if head.trim().is_empty() && tail.trim().is_empty() {
        Some((line_start as u32, line_end as u32))
    } else {
        Some((start as u32, end as u32))
    }
}
