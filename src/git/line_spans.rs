use crate::ffi::HighlightSpan;
use crate::highlight::{Lang, source_highlights};

#[derive(Debug, Default)]
pub struct LineSpans {
    lines: Vec<Vec<HighlightSpan>>,
}

impl LineSpans {
    pub fn new(lang: Lang, text: &str) -> Self {
        let spans = source_highlights(lang, text).unwrap_or_default();
        Self::split(text, &spans)
    }

    pub fn line(&self, number: Option<u32>) -> Vec<HighlightSpan> {
        number
            .and_then(|n| self.lines.get((n as usize).checked_sub(1)?))
            .cloned()
            .unwrap_or_default()
    }

    fn split(text: &str, spans: &[HighlightSpan]) -> Self {
        let bounds = line_bounds(text);
        let mut lines = vec![Vec::new(); bounds.len()];
        for span in spans {
            let (span_start, span_end) = (span.start_byte as usize, span.end_byte as usize);
            let first = bounds.partition_point(|&(_, end)| end <= span_start);
            for (index, &(start, end)) in bounds.iter().enumerate().skip(first) {
                if start >= span_end {
                    break;
                }
                let (from, to) = (span_start.max(start), span_end.min(end));
                if from < to {
                    lines[index].push(HighlightSpan {
                        start_byte: (from - start) as u32,
                        end_byte: (to - start) as u32,
                        capture: span.capture,
                    });
                }
            }
        }
        Self { lines }
    }
}

fn line_bounds(text: &str) -> Vec<(usize, usize)> {
    let mut out = Vec::new();
    let mut start = 0;
    for line in text.split_inclusive('\n') {
        let content = line.trim_end_matches('\n').trim_end_matches('\r');
        out.push((start, start + content.len()));
        start += line.len();
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::CaptureKind;

    #[test]
    fn spans_are_split_per_line_and_made_relative() {
        let text = "let a = 1;\r\n/* one\ntwo */ x\n";
        let lines = LineSpans::new(Lang::Rust, text);
        let first = lines.line(Some(1));
        assert!(
            first
                .iter()
                .any(|s| s.capture == CaptureKind::Keyword && s.start_byte == 0 && s.end_byte == 3)
        );
        let second = lines.line(Some(2));
        assert!(
            second
                .iter()
                .any(|s| s.capture == CaptureKind::Comment && (s.start_byte, s.end_byte) == (0, 6))
        );
        let third = lines.line(Some(3));
        assert!(
            third
                .iter()
                .any(|s| s.capture == CaptureKind::Comment && (s.start_byte, s.end_byte) == (0, 6))
        );
        assert!(lines.line(Some(9)).is_empty());
        assert!(lines.line(None).is_empty());
    }
}
