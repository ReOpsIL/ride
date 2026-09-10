use crate::ffi::{CompletionQuery, CompletionResponse};
use crate::highlight::{Site, SiteAt};
use crate::query;

use super::snapshot::{self, Snapshot};
use super::{Engine, access, identifier, includes, lists, paths};

pub fn run(engine: &Engine, mut q: CompletionQuery) -> CompletionResponse {
    let (kind, prefix) = query::parse_prefix(&q.prefix, q.kind_filter);
    q.kind_filter = kind.or(q.kind_filter);
    q.prefix = prefix;
    if q.limit == 0 {
        q.limit = 20;
    }
    let (query_id, session_id) = (q.query_id, q.session_id);
    let Some(snap) = snapshot::take(engine, &q, q.limit) else {
        return CompletionResponse::empty(query_id);
    };
    let resp = match snap.site.clone() {
        Some(site) => with_site(&snap, q, &site),
        None => query::run_query(
            snap.catalog.src(),
            q,
            snap.lang,
            Vec::new(),
            &snap.catalog.overlay,
        ),
    };
    if !snapshot::is_latest(engine, session_id, query_id) {
        return CompletionResponse::empty(query_id);
    }
    resp
}

fn with_site(snap: &Snapshot, mut q: CompletionQuery, site: &SiteAt) -> CompletionResponse {
    q.prefix = site.prefix.clone();
    q.replace_start_byte = site.replace_start as u32;
    q.context = site.context();
    let resp = match &site.site {
        Site::None => CompletionResponse::empty(q.query_id),
        Site::Identifier(_) => identifier::hits(snap, &q),
        Site::MemberAccess | Site::StructLiteral(_) => access::hits(snap, &q),
        Site::UsePath(segments) => paths::use_hits(snap, &q, segments),
        Site::ScopedPath(segments) => paths::scoped_hits(snap, &q, segments),
        Site::Include { quoted, dir } => includes::hits(snap, &q, *quoted, dir),
        Site::Directive => lists::directives(&q),
        Site::Attribute { derive } => lists::attributes(snap, &q, *derive),
    };
    resp.at(site.replace_start as u32, site.kind())
}
