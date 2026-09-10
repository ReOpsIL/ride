use crate::ffi::CaptureKind;
use crate::highlight::{Lang, source_highlights};

pub fn code_to_html(lang: Lang, code: &str) -> String {
    let spans = source_highlights(lang, code).unwrap_or_default();
    let mut out = String::with_capacity(code.len() * 2);
    let mut cursor = 0usize;
    for span in spans {
        let start = span.start_byte as usize;
        let end = (span.end_byte as usize).min(code.len());
        if start < cursor || start >= end {
            continue;
        }
        push_escaped(&mut out, &code[cursor..start]);
        out.push_str("<span class=\"tk-");
        out.push_str(class(span.capture));
        out.push_str("\">");
        push_escaped(&mut out, &code[start..end]);
        out.push_str("</span>");
        cursor = end;
    }
    push_escaped(&mut out, &code[cursor..]);
    out
}

fn class(kind: CaptureKind) -> &'static str {
    match kind {
        CaptureKind::Keyword => "keyword",
        CaptureKind::Function => "function",
        CaptureKind::Type => "type",
        CaptureKind::Property => "property",
        CaptureKind::Variable => "variable",
        CaptureKind::Constant => "constant",
        CaptureKind::String => "string",
        CaptureKind::Escape => "escape",
        CaptureKind::Comment => "comment",
        CaptureKind::Attribute => "attribute",
        CaptureKind::Lifetime => "lifetime",
        CaptureKind::Macro => "macro",
        CaptureKind::Number => "number",
        CaptureKind::Operator => "operator",
        CaptureKind::Punctuation => "punctuation",
        CaptureKind::Label => "label",
        CaptureKind::Heading => "heading",
        CaptureKind::Emphasis => "emphasis",
        CaptureKind::Strong => "strong",
        CaptureKind::Link => "link",
    }
}

fn push_escaped(out: &mut String, text: &str) {
    for c in text.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            _ => out.push(c),
        }
    }
}
