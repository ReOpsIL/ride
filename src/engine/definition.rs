use std::collections::HashSet;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use tree_sitter::Node;

use crate::ffi::{CompletionHit, DefinitionExcerpt};
use crate::highlight::{Lang, source_highlights};

use super::Engine;
use super::doc_block;

const MAX_LINES: usize = 60;

#[uniffi::export]
impl Engine {
    pub fn quick_definition(&self, session_id: u64, cursor_byte: u32) -> Vec<DefinitionExcerpt> {
        catch_unwind(AssertUnwindSafe(|| build(self, session_id, cursor_byte))).unwrap_or_default()
    }
}

struct Ctx {
    replica: String,
    lang: Lang,
    path: Option<String>,
}

struct Loaded {
    text: String,
    lang: Lang,
    path: String,
}

fn build(engine: &Engine, session_id: u64, cursor_byte: u32) -> Vec<DefinitionExcerpt> {
    let ctx = session(engine, session_id);
    let hits = engine.find_definitions(session_id, cursor_byte).hits;
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for hit in hits {
        let loaded = load(&hit, ctx.as_ref());
        let key = (loaded.path.clone(), hit.byte_start.unwrap_or(0));
        if !seen.insert(key) {
            continue;
        }
        if let Some(excerpt) = excerpt(&hit, &loaded) {
            out.push(excerpt);
        }
    }
    out.sort_by_key(|e| rank(&e.label));
    out
}

fn session(engine: &Engine, session_id: u64) -> Option<Ctx> {
    engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            Some(Ctx {
                replica: session.replica().to_string(),
                lang: session.lang(),
                path: session.path().map(|p| p.display().to_string()),
            })
        })
        .ok()
        .flatten()
}

fn load(hit: &CompletionHit, ctx: Option<&Ctx>) -> Loaded {
    if let Some(ctx) = ctx
        && use_buffer(hit, ctx)
    {
        return Loaded {
            text: ctx.replica.clone(),
            lang: ctx.lang,
            path: ctx.path.clone().unwrap_or_default(),
        };
    }
    let path = hit.source_path.clone().unwrap_or_default();
    let text = std::fs::read_to_string(&path).unwrap_or_default();
    let lang = Lang::for_buffer(Some(&path), &text);
    Loaded { text, lang, path }
}

fn use_buffer(hit: &CompletionHit, ctx: &Ctx) -> bool {
    match (hit.source_path.as_deref(), ctx.path.as_deref()) {
        (None, _) => true,
        (Some(a), Some(b)) => Path::new(a) == Path::new(b),
        (Some(_), None) => false,
    }
}

fn excerpt(hit: &CompletionHit, loaded: &Loaded) -> Option<DefinitionExcerpt> {
    if loaded.text.is_empty() {
        return None;
    }
    let (start, end) = range(hit, loaded)?;
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
        label: label(loaded.lang, &loaded.text, start),
        highlights,
        byte_start: start as u32,
    })
}

fn range(hit: &CompletionHit, loaded: &Loaded) -> Option<(usize, usize)> {
    let start = hit.byte_start.unwrap_or(0) as usize;
    let end = hit.byte_end.unwrap_or(0) as usize;
    if end > start {
        return Some((start, end.min(loaded.text.len())));
    }
    doc_block::item_range(loaded.lang, &loaded.text, start)
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

fn label(lang: Lang, source: &str, byte: usize) -> String {
    let Some(tree) = doc_block::parse(lang, source) else {
        return String::new();
    };
    let last = source.len().saturating_sub(1);
    let Some(node) = doc_block::item_at(tree.root_node(), byte.min(last)) else {
        return String::new();
    };
    if has_parent(node, "trait_item") {
        return "trait".into();
    }
    if let Some(ty) = impl_type(node, source) {
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

fn rank(label: &str) -> u8 {
    match label {
        "declaration" | "trait" => 0,
        "definition" => 1,
        s if s.starts_with("impl ") => 1,
        _ => 2,
    }
}
