use tree_sitter::{Node, Tree};

use crate::ffi::{CompletionHit, DefinitionExcerpt};
use crate::highlight::source_highlights;

use super::doc_block;
use super::hit_source::Loaded;

const MAX_LINES: usize = 60;

pub struct Parsed {
    pub loaded: Loaded,
    tree: Option<Tree>,
}

impl Parsed {
    pub fn new(loaded: Loaded) -> Self {
        let tree = (!loaded.text.is_empty())
            .then(|| doc_block::parse(loaded.lang, &loaded.text))
            .flatten();
        Self { loaded, tree }
    }

    fn item_at(&self, byte: usize) -> Option<Node<'_>> {
        let last = self.loaded.text.len().saturating_sub(1);
        doc_block::item_at(self.tree.as_ref()?.root_node(), byte.min(last))
    }
}

pub fn of(hit: &CompletionHit, parsed: &Parsed) -> Option<DefinitionExcerpt> {
    let loaded = &parsed.loaded;
    if loaded.text.is_empty() {
        return None;
    }
    let (start, end) = range(hit, parsed)?;
    let raw = loaded.text.get(start..end)?;
    if raw.trim().is_empty() {
        return None;
    }
    let (text, truncated) = cap(raw);
    let highlights = source_highlights(loaded.lang, &text).unwrap_or_default();
    Some(DefinitionExcerpt {
        path: loaded.path.clone(),
        line: doc_block::line_at(&loaded.text, start),
        text,
        truncated,
        label: label(parsed, start),
        highlights,
        byte_start: start as u32,
    })
}

fn range(hit: &CompletionHit, parsed: &Parsed) -> Option<(usize, usize)> {
    let len = parsed.loaded.text.len();
    let start = hit.byte_start.unwrap_or(0) as usize;
    let end = hit.byte_end.unwrap_or(0) as usize;
    if end > start {
        return Some((start, end.min(len)));
    }
    let node = parsed.item_at(start)?;
    Some((node.start_byte(), node.end_byte().min(len)))
}

fn cap(text: &str) -> (String, bool) {
    let mut n = 0;
    for (i, c) in text.char_indices() {
        if c == '\n' {
            n += 1;
            if n == MAX_LINES {
                return (text[..i].to_string(), i + 1 < text.len());
            }
        }
    }
    (text.to_string(), false)
}

fn label(parsed: &Parsed, byte: usize) -> String {
    let Some(node) = parsed.item_at(byte) else {
        return String::new();
    };
    if has_parent(node, "trait_item") {
        return "trait".into();
    }
    if let Some(ty) = impl_type(node, &parsed.loaded.text) {
        return format!("impl for {ty}");
    }
    match node.kind() {
        "declaration" | "function_signature_item" => "declaration".into(),
        _ => "definition".into(),
    }
}

fn has_parent(mut node: Node<'_>, kind: &str) -> bool {
    while let Some(parent) = node.parent() {
        if parent.kind() == kind {
            return true;
        }
        node = parent;
    }
    false
}

fn impl_type(mut node: Node<'_>, source: &str) -> Option<String> {
    loop {
        if node.kind() == "impl_item" {
            let ty = node.child_by_field_name("type")?;
            let text = ty.utf8_text(source.as_bytes()).ok()?;
            let name = text
                .split('<')
                .next()
                .unwrap_or(text)
                .rsplit("::")
                .next()
                .unwrap_or(text)
                .trim()
                .trim_matches(['&', '*']);
            return (!name.is_empty()).then(|| name.to_string());
        }
        node = node.parent()?;
    }
}
