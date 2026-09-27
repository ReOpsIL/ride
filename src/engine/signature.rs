use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{ByteRange, CompletionHit, ItemKind, SignatureHelp};
use crate::highlight::{BufferSession, CallSite};
use crate::params;

use super::catalog::Catalog;
use super::reach::Reach;
use super::{Engine, header_hits};

const CALLABLE: &[ItemKind] = &[ItemKind::Fn, ItemKind::Method, ItemKind::Macro];

#[uniffi::export]
impl Engine {
    pub fn signature_help(&self, session_id: u64, cursor_byte: u32) -> Option<SignatureHelp> {
        catch_unwind(AssertUnwindSafe(|| help(self, session_id, cursor_byte)))
            .ok()
            .flatten()
    }
}

fn help(engine: &Engine, session_id: u64, cursor_byte: u32) -> Option<SignatureHelp> {
    let snap = engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            let call = session.call_site(cursor_byte)?;
            Some((
                local_hits(session, &call),
                call,
                session.lang().has_catalog(),
                Reach::take(i, session_id, session),
                Catalog::of(i),
            ))
        })
        .ok()
        .flatten()?;
    let (mut hits, call, catalog, reach, cat) = snap;
    if hits.iter().all(|h| h.signature.is_empty()) {
        hits.extend(callable(header_hits::definitions(
            reach.headers(),
            &call.name,
        )));
        reach.remember(engine);
    }
    if catalog && hits.iter().all(|h| h.signature.is_empty()) {
        hits.extend(callable(cat.exact(
            &call.name,
            call.qualifier.as_deref(),
            10,
        )));
    }
    let hit = hits.into_iter().find(|h| !h.signature.is_empty())?;
    build(&call, &hit)
}

fn local_hits(session: &BufferSession, call: &CallSite) -> Vec<CompletionHit> {
    session
        .outline()
        .iter()
        .filter(|o| o.name == call.name && CALLABLE.contains(&o.kind))
        .map(|o| {
            let mut hit = CompletionHit::from_outline(o, 0.0, None);
            if hit.signature.is_empty() {
                hit.signature = declaration_head(session.replica(), o.start_byte as usize);
            }
            hit
        })
        .collect()
}

fn callable(hits: Vec<CompletionHit>) -> impl Iterator<Item = CompletionHit> {
    hits.into_iter().filter(|h| CALLABLE.contains(&h.item_kind))
}

fn declaration_head(text: &str, start: usize) -> String {
    let rest = &text[start.min(text.len())..];
    let limit = rest.char_indices().nth(200).map_or(rest.len(), |(i, _)| i);
    let end = rest.find(['{', ';']).unwrap_or(limit);
    rest[..end].split_whitespace().collect::<Vec<_>>().join(" ")
}

fn build(call: &CallSite, hit: &CompletionHit) -> Option<SignatureHelp> {
    let label = hit.signature.clone();
    let parsed = params::parse(&label, &hit.name)?;
    let parameters: Vec<ByteRange> = parsed
        .ranges
        .iter()
        .map(|(s, e)| ByteRange {
            start_byte: *s as u32,
            end_byte: *e as u32,
        })
        .collect();
    let last = parameters.len().saturating_sub(1) as u32;
    Some(SignatureHelp {
        label,
        active_parameter: call.active_parameter.min(last),
        parameters,
        doc: hit.doc_first_sentence.clone(),
        name: hit.name.clone(),
    })
}
