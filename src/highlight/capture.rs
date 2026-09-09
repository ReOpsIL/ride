use crate::ffi::CaptureKind;

pub fn capture_kind(name: &str) -> CaptureKind {
    let base = name.split('.').next().unwrap_or(name);
    match base {
        "keyword" => CaptureKind::Keyword,
        "function" => CaptureKind::Function,
        "type" => CaptureKind::Type,
        "property" => CaptureKind::Property,
        "variable" => CaptureKind::Variable,
        "constant" | "constructor" => CaptureKind::Constant,
        "string" => CaptureKind::String,
        "escape" => CaptureKind::Escape,
        "comment" => CaptureKind::Comment,
        "attribute" => CaptureKind::Attribute,
        "lifetime" => CaptureKind::Lifetime,
        "macro" => CaptureKind::Macro,
        "number" => CaptureKind::Number,
        "operator" => CaptureKind::Operator,
        "punctuation" => CaptureKind::Punctuation,
        "label" => CaptureKind::Label,
        "heading" => CaptureKind::Heading,
        "emphasis" => CaptureKind::Emphasis,
        "strong" => CaptureKind::Strong,
        "link" => CaptureKind::Link,
        _ => CaptureKind::Variable,
    }
}
