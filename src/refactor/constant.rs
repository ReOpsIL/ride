use crate::ffi::{ByteRange, ExtractPlan, TextEdit};
use crate::highlight::{BufferSession, Lang};
use crate::text::indent_at;

use super::literal_type::type_name;
use super::name::placeholder;

const BASE: &str = "VALUE";

pub fn introduce_constant(
    session: &BufferSession,
    start_byte: u32,
    end_byte: u32,
) -> Option<ExtractPlan> {
    let lang = session.lang();
    let text = session.replica();
    let spans = session.constant_spans(ByteRange {
        start_byte,
        end_byte,
    })?;
    let literal = text.get(spans.literal.start_byte as usize..spans.literal.end_byte as usize)?;
    let ty = type_name(lang, spans.kind, literal, spans.context)?;
    let name = placeholder(text, BASE);
    let anchor = spans.anchor.start_byte;
    let indent = indent_at(text, anchor as usize);
    let prefix = prefix(lang, ty);
    let declaration = format!("{prefix}{name}{}", tail(lang, ty, literal, &indent));
    let select_start = anchor + prefix.len() as u32;
    let select_end = select_start + name.len() as u32;
    let edits = vec![
        TextEdit {
            start_byte: anchor,
            end_byte: anchor,
            text: declaration,
            caret_byte: anchor,
        },
        TextEdit {
            start_byte: spans.literal.start_byte,
            end_byte: spans.literal.end_byte,
            text: name.clone(),
            caret_byte: spans.literal.start_byte,
        },
    ];
    Some(ExtractPlan {
        edits,
        name,
        select_start,
        select_end,
    })
}

fn prefix(lang: Lang, ty: &str) -> String {
    match lang {
        Lang::Rust => "const ".to_string(),
        Lang::Cpp => format!("constexpr {ty} "),
        _ => format!("static const {ty} "),
    }
}

fn tail(lang: Lang, ty: &str, literal: &str, indent: &str) -> String {
    match lang {
        Lang::Rust => format!(": {ty} = {literal};\n\n{indent}"),
        _ => format!(" = {literal};\n\n{indent}"),
    }
}
