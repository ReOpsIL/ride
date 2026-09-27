use crate::highlight::Lang;

use super::literal::{LiteralContext, LiteralKind};

const INT_SUFFIXES: [&str; 12] = [
    "u128", "i128", "usize", "isize", "u64", "i64", "u32", "i32", "u16", "i16", "u8", "i8",
];

const FLOAT_SUFFIXES: [&str; 2] = ["f32", "f64"];

pub fn type_name(
    lang: Lang,
    kind: LiteralKind,
    literal: &str,
    context: LiteralContext,
) -> Option<&'static str> {
    match lang {
        Lang::Rust => Some(rust_type(kind, literal, context)),
        Lang::C if context == LiteralContext::ConstantExpr => None,
        Lang::C | Lang::Cpp => Some(c_type(kind, literal)),
        _ => None,
    }
}

fn rust_type(kind: LiteralKind, literal: &str, context: LiteralContext) -> &'static str {
    match kind {
        LiteralKind::Int => suffix(literal, &INT_SUFFIXES).unwrap_or_else(|| {
            if context == LiteralContext::Index {
                "usize"
            } else {
                rust_int(literal)
            }
        }),
        LiteralKind::Float => suffix(literal, &FLOAT_SUFFIXES).unwrap_or("f64"),
        LiteralKind::Str if literal.starts_with('b') => "&[u8]",
        LiteralKind::Str if literal.starts_with('c') => "&core::ffi::CStr",
        LiteralKind::Str => "&str",
        LiteralKind::Char if literal.starts_with('b') => "u8",
        LiteralKind::Char => "char",
        LiteralKind::Bool => "bool",
    }
}

fn c_type(kind: LiteralKind, literal: &str) -> &'static str {
    match kind {
        LiteralKind::Int => match int_value(literal) {
            Some(v) if fits(v, i32::MIN.into(), i32::MAX.into()) => "int",
            _ => "long long",
        },
        LiteralKind::Float => "double",
        LiteralKind::Str => "const char*",
        LiteralKind::Char => "char",
        LiteralKind::Bool => "bool",
    }
}

fn suffix(literal: &str, suffixes: &[&'static str]) -> Option<&'static str> {
    let hex = literal
        .trim_start_matches('-')
        .trim_start()
        .to_ascii_lowercase()
        .starts_with("0x");
    suffixes
        .iter()
        .copied()
        .find(|s| literal.ends_with(s) && !(hex && s.starts_with('f')))
}

fn rust_int(literal: &str) -> &'static str {
    match int_value(literal) {
        Some(v) if fits(v, i32::MIN.into(), i32::MAX.into()) => "i32",
        Some(v) if fits(v, i64::MIN.into(), i64::MAX.into()) => "i64",
        _ => "u64",
    }
}

fn fits(value: i128, min: i128, max: i128) -> bool {
    (min..=max).contains(&value)
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
