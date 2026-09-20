use crate::ffi::{ByteRange, ExtractPlan, TextEdit};
use crate::highlight::{BufferSession, Lang};

use super::indent::indent_of;
use super::name::placeholder;

const BASE: &str = "value";

pub fn extract_variable(
    session: &BufferSession,
    start_byte: u32,
    end_byte: u32,
) -> Option<ExtractPlan> {
    let keyword = keyword(session.lang())?;
    let text = session.replica();
    let spans = session.extract_spans(ByteRange {
        start_byte,
        end_byte,
    })?;
    let expr = text.get(spans.expr.start_byte as usize..spans.expr.end_byte as usize)?;
    let name = placeholder(text, BASE);
    let anchor = spans.statement.start_byte;
    let indent = indent_of(text, anchor as usize);
    let declaration = format!("{keyword} {name} = {expr};\n{indent}");
    let select_start = anchor + keyword.len() as u32 + 1;
    let select_end = select_start + name.len() as u32;
    let edits = vec![
        TextEdit {
            start_byte: anchor,
            end_byte: anchor,
            text: declaration,
            caret_byte: anchor,
        },
        TextEdit {
            start_byte: spans.expr.start_byte,
            end_byte: spans.expr.end_byte,
            text: name.clone(),
            caret_byte: spans.expr.start_byte,
        },
    ];
    Some(ExtractPlan {
        edits,
        name,
        select_start,
        select_end,
    })
}

fn keyword(lang: Lang) -> Option<&'static str> {
    match lang {
        Lang::Rust => Some("let"),
        Lang::C | Lang::Cpp => Some("auto"),
        _ => None,
    }
}
