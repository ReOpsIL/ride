use crate::ffi::{ByteRange, ExtractPlan, TextEdit};
use crate::highlight::{BufferSession, Lang};

pub fn inline_variable(session: &BufferSession, cursor_byte: u32) -> Option<ExtractPlan> {
    if !matches!(session.lang(), Lang::Rust | Lang::C | Lang::Cpp) {
        return None;
    }
    let text = session.replica();
    let spans = session.inline_spans(cursor_byte)?;
    let init = text.get(spans.init.start_byte as usize..spans.init.end_byte as usize)?;
    let replacement = if spans.parenthesize {
        format!("({init})")
    } else {
        init.to_string()
    };
    let name = text
        .get(spans.name.start_byte as usize..spans.name.end_byte as usize)?
        .to_string();
    let occurrences = session.local_occurrences(spans.name.start_byte);
    if occurrences.is_empty() {
        return None;
    }
    let uses: Vec<&ByteRange> = occurrences
        .iter()
        .filter(|r| r.start_byte != spans.name.start_byte)
        .collect();
    let first = uses.first()?;
    let (removal_start, removal_end) = removal(text, spans.statement)?;
    if removal_end > first.start_byte {
        return None;
    }
    let mut edits = vec![TextEdit {
        start_byte: removal_start,
        end_byte: removal_end,
        text: String::new(),
        caret_byte: removal_start,
    }];
    for range in &uses {
        edits.push(TextEdit {
            start_byte: range.start_byte,
            end_byte: range.end_byte,
            text: replacement.clone(),
            caret_byte: range.start_byte,
        });
    }
    let select_start = first.start_byte.checked_sub(removal_end - removal_start)?;
    let select_end = select_start + replacement.len() as u32;
    Some(ExtractPlan {
        edits,
        name,
        select_start,
        select_end,
    })
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
