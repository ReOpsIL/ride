use tree_sitter::{Node, Range};

use crate::error::EngineError;
use crate::ffi::{ByteRange, HighlightSpan};

use super::syntax::{Lang, Syntax};
use super::tree_syntax::TreeSyntax;

const FENCE_LANGS: [Lang; 3] = [Lang::Rust, Lang::C, Lang::Cpp];

struct LangFences {
    lang: Lang,
    syntax: TreeSyntax,
    ranges: Vec<Range>,
}

pub struct Fences {
    per_lang: Vec<LangFences>,
}

impl Fences {
    pub fn new() -> Result<Self, EngineError> {
        let mut per_lang = Vec::new();
        for lang in FENCE_LANGS {
            let Some(grammar) = lang.grammar() else {
                continue;
            };
            per_lang.push(LangFences {
                lang,
                syntax: TreeSyntax::new(grammar)?,
                ranges: Vec::new(),
            });
        }
        Ok(Self { per_lang })
    }

    pub fn reparse(&mut self, block_root: Node<'_>, text: &str) -> Result<(), EngineError> {
        let mut found: Vec<(Lang, Range)> = Vec::new();
        collect(block_root, text, &mut found);
        for entry in &mut self.per_lang {
            entry.ranges = found
                .iter()
                .filter(|(l, _)| *l == entry.lang)
                .map(|(_, r)| *r)
                .collect();
            if entry.ranges.is_empty() {
                entry.syntax.clear();
                continue;
            }
            entry.syntax.set_included_ranges(&entry.ranges)?;
            entry.syntax.parse_full(text)?;
        }
        Ok(())
    }

    pub fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan> {
        let mut out = Vec::new();
        for entry in &self.per_lang {
            if entry.ranges.is_empty() {
                continue;
            }
            let clipped = clip(ranges, &entry.ranges);
            out.extend(entry.syntax.highlights(text, &clipped));
        }
        out
    }
}

fn clip(ranges: &[ByteRange], fences: &[Range]) -> Vec<ByteRange> {
    ranges
        .iter()
        .flat_map(|r| {
            fences.iter().filter_map(move |f| {
                let start = r.start_byte.max(f.start_byte as u32);
                let end = r.end_byte.min(f.end_byte as u32);
                (start < end).then_some(ByteRange {
                    start_byte: start,
                    end_byte: end,
                })
            })
        })
        .collect()
}

fn collect(node: Node<'_>, text: &str, out: &mut Vec<(Lang, Range)>) {
    if node.kind() == "fenced_code_block" {
        let mut cursor = node.walk();
        let children: Vec<Node<'_>> = node.named_children(&mut cursor).collect();
        let info = children
            .iter()
            .find(|c| c.kind() == "info_string")
            .and_then(|c| c.utf8_text(text.as_bytes()).ok())
            .unwrap_or("");
        if let Some(lang) = Lang::for_fence(info)
            && let Some(content) = children.iter().find(|c| c.kind() == "code_fence_content")
        {
            out.push((lang, content.range()));
        }
        return;
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        collect(child, text, out);
    }
}
