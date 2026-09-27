use pulldown_cmark::{CodeBlockKind, Event, Options, Parser, Tag, TagEnd, html};

use crate::highlight::Lang;

use super::code::code_to_html;
use super::lines::LineIndex;

struct Fence {
    lang: Option<Lang>,
    text: String,
}

struct Renderer<'a> {
    lines: LineIndex,
    depth: usize,
    fence: Option<Fence>,
    events: Vec<Event<'a>>,
}

pub fn render(text: &str) -> String {
    let mut renderer = Renderer {
        lines: LineIndex::new(text),
        depth: 0,
        fence: None,
        events: Vec::new(),
    };
    for (event, range) in Parser::new_ext(text, options()).into_offset_iter() {
        renderer.feed(event, range.start);
    }
    let mut out = String::with_capacity(text.len() * 2);
    html::push_html(&mut out, renderer.events.into_iter());
    out
}

fn options() -> Options {
    Options::ENABLE_TABLES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_HEADING_ATTRIBUTES
}

impl<'a> Renderer<'a> {
    fn feed(&mut self, event: Event<'a>, start: usize) {
        match &event {
            Event::Start(tag) => self.open(tag, start),
            Event::End(TagEnd::CodeBlock) => self.close_fence(),
            Event::End(_) => self.depth = self.depth.saturating_sub(1),
            Event::Text(code) => {
                if let Some(fence) = self.fence.as_mut().filter(|f| f.lang.is_some()) {
                    fence.text.push_str(code);
                    return;
                }
            }
            _ => {}
        }
        self.events.push(event);
    }

    fn open(&mut self, tag: &Tag<'_>, start: usize) {
        if self.depth == 0 && is_block(tag) {
            let line = self.lines.line_at(start);
            self.events.push(Event::Html(
                format!("<span class=\"ride-line\" data-line=\"{line}\"></span>").into(),
            ));
        }
        if let Tag::CodeBlock(CodeBlockKind::Fenced(info)) = tag {
            self.fence = Some(Fence {
                lang: Lang::for_fence(info),
                text: String::new(),
            });
        }
        self.depth += 1;
    }

    fn close_fence(&mut self) {
        self.depth = self.depth.saturating_sub(1);
        if let Some(Fence {
            lang: Some(lang),
            text,
        }) = self.fence.take()
        {
            self.events
                .push(Event::Html(code_to_html(lang, &text).into()));
        }
    }
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
