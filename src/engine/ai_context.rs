use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ai::{
    Budget, MAX_RELATED, Span, innermost_item, item_span, language_name, line_of, referenced,
    whole_lines,
};
use crate::ffi::{AiContext, AiSnippet, DefinitionExcerpt, OutlineItem};
use crate::highlight::Lang;
use crate::refs::extractor_for;

use super::Engine;

struct Source {
    path: String,
    lang: Lang,
    text: String,
    outline: Vec<OutlineItem>,
}

#[uniffi::export]
impl Engine {
    pub fn ai_context(
        &self,
        session_id: u64,
        start_byte: u32,
        end_byte: u32,
        budget_chars: u32,
    ) -> Option<AiContext> {
        catch_unwind(AssertUnwindSafe(|| {
            build(self, session_id, start_byte, end_byte, budget_chars)
        }))
        .ok()
        .flatten()
    }
}

fn build(engine: &Engine, session_id: u64, start: u32, end: u32, budget: u32) -> Option<AiContext> {
    let source = engine
        .read(|i| {
            i.sessions.get(&session_id).map(|s| Source {
                path: s
                    .path()
                    .map(|p| p.display().to_string())
                    .unwrap_or_default(),
                lang: s.lang(),
                text: s.replica().to_string(),
                outline: s.outline().to_vec(),
            })
        })
        .ok()
        .flatten()?;
    let mut budget = Budget::new(budget as usize);
    let focus = whole_lines(&source.text, start as usize, end as usize);
    let focus_snippet = snippet(&source, focus, "focus", &mut budget)?;
    let enclosing_item = innermost_item(&source.outline, focus);
    let enclosing = enclosing_item.and_then(|item| {
        let label = format!("enclosing {}", item.name);
        snippet(
            &source,
            whole_lines(
                &source.text,
                item.start_byte as usize,
                item.end_byte as usize,
            ),
            &label,
            &mut budget,
        )
    });
    let covered = enclosing_item.map_or(focus, item_span);
    let related = related(engine, session_id, &source, focus, covered, &mut budget);
    Some(AiContext {
        path: source.path.clone(),
        language: language_name(source.lang).to_string(),
        focus: focus_snippet,
        enclosing,
        related,
    })
}

fn snippet(source: &Source, span: Span, label: &str, budget: &mut Budget) -> Option<AiSnippet> {
    let (text, truncated) = budget.take(span.text(&source.text))?;
    Some(AiSnippet {
        path: source.path.clone(),
        line: line_of(&source.text, span.start),
        label: label.to_string(),
        text,
        truncated,
    })
}

fn related(
    engine: &Engine,
    session_id: u64,
    source: &Source,
    focus: Span,
    covered: Span,
    budget: &mut Budget,
) -> Vec<AiSnippet> {
    let records = extractor_for(source.lang).extract(source.lang, &source.text);
    let mut out: Vec<AiSnippet> = Vec::new();
    for (name, byte) in referenced(&records, focus) {
        if out.len() >= MAX_RELATED || budget.remaining() == 0 {
            break;
        }
        let excerpt = engine
            .quick_definition(session_id, byte)
            .into_iter()
            .find(|e| !already_shown(e, source, covered));
        let Some(excerpt) = excerpt else {
            continue;
        };
        if out
            .iter()
            .any(|s| s.path == excerpt.path && s.line == excerpt.line)
        {
            continue;
        }
        if let Some((text, truncated)) = budget.take(&excerpt.text) {
            out.push(AiSnippet {
                path: excerpt.path,
                line: excerpt.line,
                label: format!("{name} ({})", excerpt.label),
                text,
                truncated: truncated || excerpt.truncated,
            });
        }
    }
    out
}

fn already_shown(excerpt: &DefinitionExcerpt, source: &Source, covered: Span) -> bool {
    let same_file = excerpt.path.is_empty() || excerpt.path == source.path;
    let at = excerpt.byte_start as usize;
    same_file && covered.start <= at && at < covered.end
}
