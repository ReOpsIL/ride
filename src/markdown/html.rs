use pulldown_cmark::{CodeBlockKind, Event, Options, Parser, Tag, html};

use super::code::rust_to_html;

pub fn render(text: &str) -> String {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TASKLISTS);
    options.insert(Options::ENABLE_FOOTNOTES);
    options.insert(Options::ENABLE_HEADING_ATTRIBUTES);
    let lines = LineIndex::new(text);
    let mut depth = 0usize;
    let mut code_lang: Option<String> = None;
    let mut events: Vec<Event<'_>> = Vec::new();
    for (event, range) in Parser::new_ext(text, options).into_offset_iter() {
        match &event {
            Event::Start(tag) => {
                if depth == 0 && is_block(tag) {
                    let line = lines.line_at(range.start);
                    events.push(Event::Html(
                        format!("<span class=\"ride-line\" data-line=\"{line}\"></span>").into(),
                    ));
                }
                if let Tag::CodeBlock(CodeBlockKind::Fenced(info)) = tag {
                    code_lang = Some(info.to_string());
                }
                depth += 1;
            }
            Event::End(_) => {
                depth = depth.saturating_sub(1);
                if code_lang.is_some()
                    && matches!(event, Event::End(pulldown_cmark::TagEnd::CodeBlock))
                {
                    code_lang = None;
                }
            }
            Event::Text(code) if code_lang.as_deref().is_some_and(is_rust) => {
                events.push(Event::Html(rust_to_html(code).into()));
                continue;
            }
            _ => {}
        }
        events.push(event);
    }
    let mut out = String::with_capacity(text.len() * 2);
    html::push_html(&mut out, events.into_iter());
    out
}

fn is_block(tag: &Tag<'_>) -> bool {
    matches!(
        tag,
        Tag::Paragraph
            | Tag::Heading { .. }
            | Tag::CodeBlock(_)
            | Tag::Table(_)
            | Tag::List(_)
            | Tag::BlockQuote(_)
            | Tag::HtmlBlock
    )
}

fn is_rust(info: &str) -> bool {
    crate::highlight::is_rust_fence(info)
}

struct LineIndex {
    starts: Vec<usize>,
}

impl LineIndex {
    fn new(text: &str) -> Self {
        let mut starts = vec![0];
        for (i, b) in text.bytes().enumerate() {
            if b == b'\n' {
                starts.push(i + 1);
            }
        }
        Self { starts }
    }

    fn line_at(&self, byte: usize) -> usize {
        match self.starts.binary_search(&byte) {
            Ok(i) => i + 1,
            Err(i) => i,
        }
    }
}
