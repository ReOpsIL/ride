use crate::ffi::{ByteRange, ExtractPlan, TextEdit};
use crate::highlight::{BufferSession, Lang};

use super::indent::indent_of;
use super::literal::LiteralKind;
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
    let ty = type_name(lang, spans.kind, literal)?;
    let name = placeholder(text, BASE);
    let anchor = spans.anchor.start_byte;
    let indent = indent_of(text, anchor as usize);
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

fn type_name(lang: Lang, kind: LiteralKind, literal: &str) -> Option<&'static str> {
    match lang {
        Lang::Rust => Some(match kind {
            LiteralKind::Int => rust_int(literal),
            LiteralKind::Float => "f64",
            LiteralKind::Str => "&str",
            LiteralKind::Char => "char",
            LiteralKind::Bool => "bool",
        }),
        Lang::C | Lang::Cpp => Some(match kind {
            LiteralKind::Int => c_int(literal),
            LiteralKind::Float => "double",
            LiteralKind::Str => "const char*",
            LiteralKind::Char => "char",
            LiteralKind::Bool => "bool",
        }),
        _ => None,
    }
}

fn rust_int(literal: &str) -> &'static str {
    match int_value(literal) {
        Some(v) if fits_i32(v) => "i32",
        Some(v) if fits_i64(v) => "i64",
        _ => "u64",
    }
}

fn c_int(literal: &str) -> &'static str {
    match int_value(literal) {
        Some(v) if fits_i32(v) => "int",
        _ => "long long",
    }
}

fn fits_i32(value: i128) -> bool {
    value >= i128::from(i32::MIN) && value <= i128::from(i32::MAX)
}

fn fits_i64(value: i128) -> bool {
    value >= i128::from(i64::MIN) && value <= i128::from(i64::MAX)
}

fn int_value(literal: &str) -> Option<i128> {
    let cleaned: String = literal.chars().filter(|c| *c != '_').collect();
    let (negative, rest) = match cleaned.strip_prefix('-') {
        Some(rest) => (true, rest.trim_start()),
        None => (false, cleaned.as_str()),
    };
    let (radix, digits) = radix_of(rest);
    let body: String = digits.chars().take_while(|c| c.is_digit(radix)).collect();
    let value = i128::from_str_radix(&body, radix).ok()?;
    Some(if negative { -value } else { value })
}

fn radix_of(literal: &str) -> (u32, &str) {
    match literal.get(..2).map(str::to_ascii_lowercase).as_deref() {
        Some("0x") => (16, literal.get(2..).unwrap_or_default()),
        Some("0b") => (2, literal.get(2..).unwrap_or_default()),
        Some("0o") => (8, literal.get(2..).unwrap_or_default()),
        _ => (10, literal),
    }
}
