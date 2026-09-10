use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::{ByteRange, CompletionHit, ItemKind, SignatureHelp};
use crate::highlight::CallSite;
use crate::params;
use crate::query::exact_search;

use super::snapshot::Catalog;
use super::{Engine, header_hits, include_graph};

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
            let local: Vec<CompletionHit> = session
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
                .collect();
            Some((
                call,
                local,
                session.lang().has_catalog(),
                session.scope(),
                i.headers.clone(),
                Catalog {
                    index_dir: i.config.index_dir.clone(),
                    index: i.index.clone(),
                    reader: i.reader.clone(),
                    overlay: i.overlay.clone(),
                },
            ))
        })
        .ok()
        .flatten()?;
    let (call, mut hits, catalog, scope, headers, cat) = snap;
    if hits.iter().all(|h| h.signature.is_empty()) {
        let reachable = include_graph::reachable(&headers, &scope);
        hits.extend(
            header_hits::definitions(&reachable, &call.name)
                .into_iter()
                .filter(|h| CALLABLE.contains(&h.item_kind)),
        );
    }
    if catalog && hits.iter().all(|h| h.signature.is_empty()) {
        hits.extend(
            exact_search(cat.src(), &call.name, call.qualifier.as_deref(), 10)
                .into_iter()
                .filter(|h| CALLABLE.contains(&h.item_kind)),
        );
    }
    let hit = hits.into_iter().find(|h| !h.signature.is_empty())?;
    build(&call, &hit)
}

fn declaration_head(text: &str, start: usize) -> String {
    let rest = &text[start.min(text.len())..];
    let end = rest.find(['{', ';']).unwrap_or_else(|| rest.len().min(200));
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
