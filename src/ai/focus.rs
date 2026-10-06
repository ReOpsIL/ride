use crate::ffi::OutlineItem;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Span {
    pub start: usize,
    pub end: usize,
}

impl Span {
    pub fn contains(&self, other: Span) -> bool {
        self.start <= other.start && other.end <= self.end
    }

    pub fn text<'a>(&self, source: &'a str) -> &'a str {
        source.get(self.start..self.end).unwrap_or_default()
    }
}

pub fn whole_lines(text: &str, start: usize, end: usize) -> Span {
    let start = floor(text, start.min(text.len()));
    let end = floor(text, end.max(start).min(text.len()));
    let line_start = text[..start].rfind('\n').map_or(0, |i| i + 1);
    let line_end = if end > line_start && text[..end].ends_with('\n') {
        end
    } else {
        text[end..].find('\n').map_or(text.len(), |i| end + i + 1)
    };
    Span {
        start: line_start,
        end: line_end,
    }
}

pub fn innermost_item(outline: &[OutlineItem], focus: Span) -> Option<&OutlineItem> {
    outline
        .iter()
        .filter(|item| {
            let span = item_span(item);
            span.contains(focus) && span != focus
        })
        .min_by_key(|item| item.end_byte - item.start_byte)
}

pub fn item_span(item: &OutlineItem) -> Span {
    Span {
        start: item.start_byte as usize,
        end: item.end_byte as usize,
    }
}

pub fn line_of(text: &str, byte: usize) -> u32 {
    text[..floor(text, byte.min(text.len()))]
        .matches('\n')
        .count() as u32
        + 1
}

fn floor(text: &str, mut byte: usize) -> usize {
    while !text.is_char_boundary(byte) {
        byte -= 1;
    }
    byte
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_caret_or_partial_selection_widens_to_whole_lines() {
        let text = "one\ntwo three\nfour\n";
        assert_eq!(whole_lines(text, 6, 6).text(text), "two three\n");
        assert_eq!(whole_lines(text, 5, 15).text(text), "two three\nfour\n");
        assert_eq!(whole_lines(text, 0, text.len()).text(text), text);
        assert_eq!(line_of(text, 6), 2);
    }
}
