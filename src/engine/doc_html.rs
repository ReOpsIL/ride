use std::ops::Range;

use pulldown_cmark::{Event, Options, Parser};

const PASSES: usize = 4;

pub fn inert(markdown: &str) -> String {
    let mut text = markdown.to_string();
    for _ in 0..PASSES {
        let spans = raw_html(&text);
        if spans.is_empty() {
            return text;
        }
        text = escape_spans(&text, &spans);
    }
    text.replace('<', "&lt;")
}

fn raw_html(text: &str) -> Vec<Range<usize>> {
    Parser::new_ext(text, options())
        .into_offset_iter()
        .filter(|(event, _)| matches!(event, Event::Html(_) | Event::InlineHtml(_)))
        .map(|(_, range)| range)
        .collect()
}

fn options() -> Options {
    Options::ENABLE_TABLES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_HEADING_ATTRIBUTES
}

fn escape_spans(text: &str, spans: &[Range<usize>]) -> String {
    let mut out = String::with_capacity(text.len() + spans.len() * 8);
    let mut at = 0;
    for span in spans {
        let Some(raw) = text.get(span.clone()).filter(|_| span.start >= at) else {
            continue;
        };
        out.push_str(&text[at..span.start]);
        out.push_str(&raw.replace('<', "&lt;"));
        at = span.end;
    }
    out.push_str(&text[at..]);
    out
}
